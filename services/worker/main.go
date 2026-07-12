package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

// Event represents a message from SQS.
type Event struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp string                 `json:"timestamp"`
}

func main() {
	sqsQueue := os.Getenv("SQS_QUEUE_URL")
	if sqsQueue == "" {
		log.Fatal("SQS_QUEUE_URL is required")
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("failed to load AWS configuration: %v", err)
	}

	sqsClient := sqs.NewFromConfig(cfg)

	httpClient := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Internal service URLs for event-driven calls.
	services := map[string]string{
		"inventory":    getEnv("INVENTORY_SERVICE_URL", "http://inventory-service:8082"),
		"payment":      getEnv("PAYMENT_SERVICE_URL", "http://payment-service:8083"),
		"notification": getEnv("NOTIFICATION_SERVICE_URL", "http://notification-service:8084"),
		"shipping":     getEnv("SHIPPING_SERVICE_URL", "http://shipping-service:8085"),
		"order":        getEnv("ORDER_SERVICE_URL", "http://order-service:8081"),
	}

	// Health-check endpoints.
	go func() {
		mux := http.NewServeMux()

		mux.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")

			if err := json.NewEncoder(w).Encode(map[string]string{
				"status":  "ok",
				"service": "worker",
			}); err != nil {
				log.Printf("failed to write health-check response: %v", err)
			}
		})

		port := getEnv("HEALTH_PORT", "8090")

		log.Printf("Worker health check on :%s", port)

		if err := http.ListenAndServe(":"+port, mux); err != nil {
			log.Printf("health-check server stopped: %v", err)
		}
	}()

	// Graceful shutdown.
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Shutting down worker...")
		cancel()
	}()

	log.Println("Worker started, polling SQS for events...")

	pollAndProcess(
		ctx,
		sqsClient,
		httpClient,
		sqsQueue,
		services,
	)
}

func pollAndProcess(
	ctx context.Context,
	sqsClient *sqs.Client,
	httpClient *http.Client,
	queueURL string,
	services map[string]string,
) {
	for {
		select {
		case <-ctx.Done():
			log.Println("Worker stopped")
			return

		default:
			messages, err := receiveSQSMessages(
				ctx,
				sqsClient,
				queueURL,
			)
			if err != nil {
				if ctx.Err() != nil {
					return
				}

				log.Printf("Failed to receive SQS messages: %v", err)
				time.Sleep(5 * time.Second)
				continue
			}

			for _, message := range messages {
				if message.Body == nil {
					log.Println("Received SQS message with no body")
					continue
				}

				var event Event

				if err := json.Unmarshal(
					[]byte(aws.ToString(message.Body)),
					&event,
				); err != nil {
					log.Printf(
						"Failed to parse SQS message %s: %v",
						aws.ToString(message.MessageId),
						err,
					)

					// Do not delete the message.
					// SQS can retry it and eventually send it to the DLQ.
					continue
				}

				log.Printf("Processing event: %s", event.Type)

				if err := handleEvent(
					httpClient,
					services,
					event,
				); err != nil {
					log.Printf(
						"Failed to handle event %s: %v",
						event.Type,
						err,
					)

					// Do not delete unsuccessful messages.
					continue
				}

				if err := deleteSQSMessage(
					ctx,
					sqsClient,
					queueURL,
					message.ReceiptHandle,
				); err != nil {
					log.Printf(
						"Event processed but SQS message could not be deleted: %v",
						err,
					)
					continue
				}

				log.Printf("Successfully processed: %s", event.Type)
			}
		}
	}
}

func handleEvent(
	httpClient *http.Client,
	services map[string]string,
	event Event,
) error {
	switch event.Type {
	case "order.created":
		// 1. Reserve inventory.
		log.Println("  -> Reserving inventory for order")

		// 2. Process payment.
		log.Println("  -> Processing payment")

		// 3. Send confirmation notification.
		log.Println("  -> Sending order confirmation")

		// 4. Update order to confirmed.
		log.Println("  -> Confirming order")

	case "order.status_changed":
		newStatus, _ := event.Payload["new_status"].(string)

		switch newStatus {
		case "processing":
			log.Println("  -> Creating shipment for order")

		case "shipped":
			log.Println("  -> Sending shipping notification")

		case "delivered":
			log.Println("  -> Sending delivery notification")

		case "cancelled":
			log.Println("  -> Releasing inventory reservation")
			log.Println("  -> Processing refund")

		default:
			log.Printf("  -> Unknown order status: %s", newStatus)
		}

	case "payment.completed":
		log.Println("  -> Payment successful, confirming order")

	case "payment.failed":
		log.Println("  -> Payment failed, cancelling order")

	case "shipment.created":
		log.Println("  -> Shipment created, updating order to processing")

	case "shipment.delivered":
		log.Println("  -> Shipment delivered, updating order")

	default:
		log.Printf("  -> Unknown event type: %s (skipping)", event.Type)
	}

	// Remove these once HTTP calls to the services are implemented.
	_ = httpClient
	_ = services

	return nil
}

func receiveSQSMessages(
	ctx context.Context,
	client *sqs.Client,
	queueURL string,
) ([]types.Message, error) {
	result, err := client.ReceiveMessage(
		ctx,
		&sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20,
			VisibilityTimeout:   60,
		},
	)
	if err != nil {
		return nil, err
	}

	return result.Messages, nil
}

func deleteSQSMessage(
	ctx context.Context,
	client *sqs.Client,
	queueURL string,
	receiptHandle *string,
) error {
	if receiptHandle == nil {
		return nil
	}

	_, err := client.DeleteMessage(
		ctx,
		&sqs.DeleteMessageInput{
			QueueUrl:      aws.String(queueURL),
			ReceiptHandle: receiptHandle,
		},
	)

	return err
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}