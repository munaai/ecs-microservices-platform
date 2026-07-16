package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
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

// Event represents a message received from SQS.
type Event struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp string                 `json:"timestamp"`
}

// ChargeResponse matches the response returned by Payment Service /charge.
type ChargeResponse struct {
	PaymentID string  `json:"payment_id"`
	OrderID   int     `json:"order_id"`
	Amount    float64 `json:"amount"`
	Currency  string  `json:"currency"`
	Status    string  `json:"status"`
}

func main() {
	queueURL := os.Getenv("SQS_QUEUE_URL")
	if queueURL == "" {
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
		Timeout: 15 * time.Second,
	}

	// ECS uses the *.internal Cloud Map addresses.
	// Environment variables can override these values.
	services := map[string]string{
		"inventory": getEnv(
			"INVENTORY_SERVICE_URL",
			"http://inventory-service.internal:8082",
		),
		"payment": getEnv(
			"PAYMENT_SERVICE_URL",
			"http://payment-service.internal:8083",
		),
		"notification": getEnv(
			"NOTIFICATION_SERVICE_URL",
			"http://notification-service.internal:8084",
		),
		"shipping": getEnv(
			"SHIPPING_SERVICE_URL",
			"http://shipping-service.internal:8085",
		),
		"order": getEnv(
			"ORDER_SERVICE_URL",
			"http://order-service.internal:8081",
		),
	}

	startHealthServer()

	signalChannel := make(chan os.Signal, 1)
	signal.Notify(
		signalChannel,
		syscall.SIGINT,
		syscall.SIGTERM,
	)

	go func() {
		<-signalChannel
		log.Println("Shutting down worker...")
		cancel()
	}()

	log.Println("Worker started, polling SQS for events...")

	pollAndProcess(
		ctx,
		sqsClient,
		httpClient,
		queueURL,
		services,
	)
}

func startHealthServer() {
	go func() {
		mux := http.NewServeMux()

		mux.HandleFunc("/livez", func(
			w http.ResponseWriter,
			_ *http.Request,
		) {
			w.WriteHeader(http.StatusOK)
		})

		mux.HandleFunc("/healthz", func(
			w http.ResponseWriter,
			_ *http.Request,
		) {
			writeJSON(w, http.StatusOK, map[string]string{
				"status":  "ok",
				"service": "worker",
			})
		})

		port := getEnv("HEALTH_PORT", "8090")

		server := &http.Server{
			Addr:              ":" + port,
			Handler:           mux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       60 * time.Second,
		}

		log.Printf("Worker health check on :%s", port)

		if err := server.ListenAndServe(); err != nil &&
			!errors.Is(err, http.ErrServerClosed) {
			log.Printf("health-check server stopped: %v", err)
		}
	}()
}

func pollAndProcess(
	ctx context.Context,
	sqsClient *sqs.Client,
	httpClient *http.Client,
	queueURL string,
	services map[string]string,
) {
	for {
		if ctx.Err() != nil {
			log.Println("Worker stopped")
			return
		}

		messages, err := receiveSQSMessages(
			ctx,
			sqsClient,
			queueURL,
		)
		if err != nil {
			if ctx.Err() != nil {
				log.Println("Worker stopped")
				return
			}

			log.Printf("Failed to receive SQS messages: %v", err)

			select {
			case <-ctx.Done():
				return
			case <-time.After(5 * time.Second):
				continue
			}
		}

		for _, message := range messages {
			if err := processMessage(
				ctx,
				sqsClient,
				httpClient,
				queueURL,
				services,
				message,
			); err != nil {
				log.Printf("Message processing failed: %v", err)

				// The message is not deleted.
				// SQS will retry it and eventually move it to the DLQ.
			}
		}
	}
}

func processMessage(
	ctx context.Context,
	sqsClient *sqs.Client,
	httpClient *http.Client,
	queueURL string,
	services map[string]string,
	message types.Message,
) error {
	if message.Body == nil {
		return errors.New("received SQS message with no body")
	}

	messageID := aws.ToString(message.MessageId)

	var event Event

	if err := json.Unmarshal(
		[]byte(aws.ToString(message.Body)),
		&event,
	); err != nil {
		return fmt.Errorf(
			"failed to parse SQS message %s: %w",
			messageID,
			err,
		)
	}

	log.Printf(
		"Processing event %q from message %s",
		event.Type,
		messageID,
	)

	if err := handleEvent(
		ctx,
		httpClient,
		services,
		event,
	); err != nil {
		return fmt.Errorf(
			"failed to handle event %q: %w",
			event.Type,
			err,
		)
	}

	if err := deleteSQSMessage(
		ctx,
		sqsClient,
		queueURL,
		message.ReceiptHandle,
	); err != nil {
		return fmt.Errorf(
			"event processed but message could not be deleted: %w",
			err,
		)
	}

	log.Printf(
		"Successfully processed and deleted event: %s",
		event.Type,
	)

	return nil
}

func handleEvent(
	ctx context.Context,
	client *http.Client,
	services map[string]string,
	event Event,
) error {
	switch event.Type {
	case "order.created":
		return handleOrderCreated(
			ctx,
			client,
			services,
			event.Payload,
		)

	// Payment Service already publishes these events.
	// The order.created workflow handles the payment response synchronously,
	// so these events can currently be acknowledged without repeating work.
	case "payment.completed":
		log.Println(
			"Payment completed event received; order workflow already handled it",
		)
		return nil

	case "payment.failed":
		log.Println(
			"Payment failed event received; order workflow already handled it",
		)
		return nil

	case "order.status_changed":
		status, _ := event.Payload["new_status"].(string)

		log.Printf(
			"Order status changed to %q; no additional worker action required",
			status,
		)

		return nil

	// Shipping is not implemented yet because order.created does not contain
	// recipient_name, address_line1, city, postcode or country.
	case "shipment.created", "shipment.delivered":
		log.Printf(
			"Event %q received; shipping workflow is not implemented yet",
			event.Type,
		)

		return nil

	default:
		log.Printf(
			"Unknown event type %q; skipping",
			event.Type,
		)

		return nil
	}
}

func handleOrderCreated(
	ctx context.Context,
	client *http.Client,
	services map[string]string,
	payload map[string]interface{},
) error {
	orderID, err := requiredValue(payload, "order_id")
	if err != nil {
		return err
	}

	items, err := requiredValue(payload, "items")
	if err != nil {
		return err
	}

	customerID, err := requiredString(payload, "customer_id")
	if err != nil {
		return err
	}

	total, err := requiredValue(payload, "total")
	if err != nil {
		return err
	}

	currency := stringOrDefault(
		payload,
		"currency",
		"GBP",
	)

	/*
		Step 1: reserve inventory.

		Inventory Service expects:

		{
		  "order_id": ...,
		  "items": [
		    {
		      "product_id": "...",
		      "quantity": ...
		    }
		  ]
		}
	*/
	reservationRequest := map[string]interface{}{
		"order_id": orderID,
		"items":    items,
	}

	log.Printf(
		"Reserving inventory for order %v",
		orderID,
	)

	if err := sendJSON(
		ctx,
		client,
		http.MethodPost,
		services["inventory"]+"/reserve",
		reservationRequest,
		nil,
	); err != nil {
		log.Printf(
			"Inventory reservation failed for order %v: %v",
			orderID,
			err,
		)

		if statusErr := updateOrderStatus(
			ctx,
			client,
			services["order"],
			orderID,
			"cancelled",
		); statusErr != nil {
			log.Printf(
				"Failed to cancel order %v after inventory failure: %v",
				orderID,
				statusErr,
			)
		}

		return fmt.Errorf(
			"inventory reservation failed: %w",
			err,
		)
	}

	/*
		Step 2: charge the customer.

		Payment Service expects:

		{
		  "order_id": ...,
		  "customer_id": "...",
		  "amount": ...,
		  "currency": "...",
		  "method": "card"
		}
	*/
	chargeRequest := map[string]interface{}{
		"order_id":    orderID,
		"customer_id": customerID,
		"amount":      total,
		"currency":    currency,
		"method":      "card",
	}

	var chargeResponse ChargeResponse

	log.Printf(
		"Processing payment for order %v",
		orderID,
	)

	if err := sendJSON(
		ctx,
		client,
		http.MethodPost,
		services["payment"]+"/charge",
		chargeRequest,
		&chargeResponse,
	); err != nil {
		releaseInventory(
			ctx,
			client,
			services["inventory"],
			orderID,
		)

		if statusErr := updateOrderStatus(
			ctx,
			client,
			services["order"],
			orderID,
			"cancelled",
		); statusErr != nil {
			log.Printf(
				"Failed to cancel order %v after payment request failure: %v",
				orderID,
				statusErr,
			)
		}

		return fmt.Errorf(
			"payment request failed: %w",
			err,
		)
	}

	// Payment Service may return a successful HTTP response containing
	// status "failed", so check the body as well as the HTTP status code.
	if chargeResponse.Status != "completed" {
		log.Printf(
			"Payment for order %v returned status %q",
			orderID,
			chargeResponse.Status,
		)

		releaseInventory(
			ctx,
			client,
			services["inventory"],
			orderID,
		)

		if statusErr := updateOrderStatus(
			ctx,
			client,
			services["order"],
			orderID,
			"cancelled",
		); statusErr != nil {
			log.Printf(
				"Failed to cancel order %v after failed payment: %v",
				orderID,
				statusErr,
			)
		}

		if notificationErr := sendNotification(
			ctx,
			client,
			services["notification"],
			customerID,
			"payment_failed",
			payload,
		); notificationErr != nil {
			log.Printf(
				"Failed to create payment-failed notification for order %v: %v",
				orderID,
				notificationErr,
			)
		}

		// This outcome was handled successfully, so return nil.
		return nil
	}

	/*
		Step 3: confirm the order.

		Order Service expects:

		{
		  "order_id": ...,
		  "new_status": "confirmed"
		}
	*/
	log.Printf(
		"Confirming order %v",
		orderID,
	)

	if err := updateOrderStatus(
		ctx,
		client,
		services["order"],
		orderID,
		"confirmed",
	); err != nil {
		return fmt.Errorf(
			"payment completed but order could not be confirmed: %w",
			err,
		)
	}

	/*
		Step 4: create an order-confirmed notification.

		Notification Service expects:

		{
		  "recipient": "...",
		  "channel": "email",
		  "template": "order_confirmed",
		  "data": {...}
		}

		customer_id currently contains admin@platform.local, so it can be used
		as the notification recipient in this project.
	*/
	log.Printf(
		"Creating confirmation notification for order %v",
		orderID,
	)

	if err := sendNotification(
		ctx,
		client,
		services["notification"],
		customerID,
		"order_confirmed",
		payload,
	); err != nil {
		// Do not fail the whole order after payment and confirmation succeeded.
		// Retrying the entire message could charge the customer twice.
		log.Printf(
			"Order %v was confirmed, but notification creation failed: %v",
			orderID,
			err,
		)
	}

	log.Printf(
		"Order %v processed successfully; payment ID: %s",
		orderID,
		chargeResponse.PaymentID,
	)

	return nil
}

func releaseInventory(
	ctx context.Context,
	client *http.Client,
	inventoryServiceURL string,
	orderID interface{},
) {
	releaseRequest := map[string]interface{}{
		"order_id": orderID,
	}

	log.Printf(
		"Releasing inventory reservation for order %v",
		orderID,
	)

	if err := sendJSON(
		ctx,
		client,
		http.MethodPost,
		inventoryServiceURL+"/release",
		releaseRequest,
		nil,
	); err != nil {
		log.Printf(
			"Failed to release inventory for order %v: %v",
			orderID,
			err,
		)
	}
}

func updateOrderStatus(
	ctx context.Context,
	client *http.Client,
	orderServiceURL string,
	orderID interface{},
	status string,
) error {
	requestBody := map[string]interface{}{
		"order_id":   orderID,
		"new_status": status,
	}

	return sendJSON(
		ctx,
		client,
		http.MethodPut,
		orderServiceURL+"/status",
		requestBody,
		nil,
	)
}

func sendNotification(
	ctx context.Context,
	client *http.Client,
	notificationServiceURL string,
	recipient string,
	template string,
	data map[string]interface{},
) error {
	requestBody := map[string]interface{}{
		"recipient": recipient,
		"channel":   "email",
		"template":  template,
		"data":      data,
	}

	return sendJSON(
		ctx,
		client,
		http.MethodPost,
		notificationServiceURL+"/send",
		requestBody,
		nil,
	)
}

// sendJSON sends a JSON request and optionally decodes the JSON response.
func sendJSON(
	ctx context.Context,
	client *http.Client,
	method string,
	url string,
	payload interface{},
	responseValue interface{},
) error {
	requestBody, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf(
			"failed to encode request body: %w",
			err,
		)
	}

	request, err := http.NewRequestWithContext(
		ctx,
		method,
		url,
		bytes.NewReader(requestBody),
	)
	if err != nil {
		return fmt.Errorf(
			"failed to create request: %w",
			err,
		)
	}

	request.Header.Set(
		"Content-Type",
		"application/json",
	)

	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf(
			"%s %s failed: %w",
			method,
			url,
			err,
		)
	}
	defer response.Body.Close()

	responseBody, err := io.ReadAll(
		io.LimitReader(response.Body, 1<<20),
	)
	if err != nil {
		return fmt.Errorf(
			"failed to read response from %s: %w",
			url,
			err,
		)
	}

	if response.StatusCode < http.StatusOK ||
		response.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf(
			"%s %s returned %d: %s",
			method,
			url,
			response.StatusCode,
			string(responseBody),
		)
	}

	if responseValue != nil && len(responseBody) > 0 {
		if err := json.Unmarshal(
			responseBody,
			responseValue,
		); err != nil {
			return fmt.Errorf(
				"%s %s returned invalid JSON: %w",
				method,
				url,
				err,
			)
		}
	}

	log.Printf(
		"%s %s returned %d",
		method,
		url,
		response.StatusCode,
	)

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
		return errors.New(
			"SQS receipt handle is missing",
		)
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

func requiredValue(
	payload map[string]interface{},
	key string,
) (interface{}, error) {
	value, exists := payload[key]
	if !exists || value == nil {
		return nil, fmt.Errorf(
			"%s is missing from event payload",
			key,
		)
	}

	return value, nil
}

func requiredString(
	payload map[string]interface{},
	key string,
) (string, error) {
	value, exists := payload[key]
	if !exists || value == nil {
		return "", fmt.Errorf(
			"%s is missing from event payload",
			key,
		)
	}

	stringValue, ok := value.(string)
	if !ok || stringValue == "" {
		return "", fmt.Errorf(
			"%s must be a non-empty string",
			key,
		)
	}

	return stringValue, nil
}

func stringOrDefault(
	payload map[string]interface{},
	key string,
	fallback string,
) string {
	value, exists := payload[key]
	if !exists || value == nil {
		return fallback
	}

	stringValue, ok := value.(string)
	if !ok || stringValue == "" {
		return fallback
	}

	return stringValue
}

func writeJSON(
	w http.ResponseWriter,
	status int,
	value interface{},
) {
	w.Header().Set(
		"Content-Type",
		"application/json",
	)

	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf(
			"failed to write JSON response: %v",
			err,
		)
	}
}

func getEnv(
	key string,
	fallback string,
) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}