<p align="center">
  <img src="images/coderco.jpg" alt="CoderCo" width="200"/>
</p>

# ECS v3 - Order Fulfillment Platform

A multi-service order platform on AWS. Nine services, one cluster. The application code is provided. You build everything else.

---

## Services

| Service | Description |
|---------|-------------|
| **api-gateway** | Auth, rate limiting, routes requests to internal services |
| **order-service** | Order lifecycle and state machine |
| **inventory-service** | Stock management and reservations |
| **payment-service** | Payment processing, refunds, ledger |
| **notification-service** | Email and SMS dispatch |
| **shipping-service** | Shipments, tracking, carrier webhooks |
| **worker** | SQS consumer, orchestrates cross-service events |
| **scheduler** | Cron jobs (expired reservations, abandoned orders, retries) |
| **dashboard-api** | Admin dashboard UI, analytics and reporting |

Read the source code. Environment variables, endpoints, and data models are in the code.

---

## Your Job

Write the Dockerfiles. Write the Terraform. Write the CI/CD pipeline. Deploy all nine services to ECS Fargate on AWS.

### Requirements

- ECS Fargate - nine separate services, one cluster
- Application Load Balancer routing to the correct services
- RDS PostgreSQL (shared database)
- ElastiCache Redis (API gateway rate limiting and caching)
- SQS queue with dead letter queue (cross-service event bus)
- ECR repositories (one per service)
- VPC with private subnets. No NAT gateways.
- Secrets in Secrets Manager or Parameter Store - not hardcoded, not in env files
- GitHub Actions with OIDC. No long-lived AWS credentials.
- Zero-downtime deployments with rollback on failure
- Least-privilege IAM - each service gets only what it needs
- Terraform with remote state
- Multi-stage Docker builds
- Container image scanning before deploy

### Deliverables

- [ ] Dockerfiles (one per service)
- [ ] Terraform for all infrastructure
- [ ] GitHub Actions CI/CD pipeline (app deploys and infra changes separated)
- [ ] Working deployment - all services healthy, end-to-end flow functional
- [ ] Dashboard UI accessible and connected to all services
- [ ] README covering the sections below

---

## What Your README Must Cover

This is not optional. Your README is part of the submission.

**Architecture decisions** - what you built, why you built it that way, what you traded off.

**Deployment pipeline** - a developer pushes a change to the payment service. Walk through exactly what happens, from commit to live traffic. How do app deploys and infra changes stay out of each other's way? What triggers what?

**Secrets management** - nine services need database credentials, API keys, JWT secrets. How do they get them? What happens when you rotate a secret?

**Scaling strategy** - which services scale and on what metric? What stays fixed? What breaks first under load?

**Database migrations** - seven services share one database. How do schema changes get deployed safely? What about rollback?

---

## Things to Consider

These aren't requirements. They're the kind of problems you'll hit in production. How you handle them is up to you.

- The worker processes events from SQS. What happens to events that fail three times?
- The payment service goes down for two minutes. What happens to in-flight orders?
- You need to add a column to the orders table. The dashboard service reads from that table. How do you deploy both without downtime?
- Nine services each open database connections. What's the max connection count on your RDS instance? What happens when you scale to three tasks per service?
- A junior dev pushes a bad image for the notification service. How quickly can you roll back without affecting the other eight?
- Fargate Spot saves money. Which services can tolerate interruption? Which absolutely cannot?
- Your logging pipeline ingests from nine services. What does that cost per month? Is there a cheaper way?
- You rotate the database password. Do all nine services restart? Is there a way to avoid that?

---

## Local Development

```bash
docker compose up --build
```

---

## Advanced: Observability

This section is not required for submission but will set your project apart.

It's 2am. Orders are failing. You're on call. You need to answer four questions fast:
1. Which of the nine services is the problem?
2. When did it start?
3. What changed?
4. Who's affected?

If your setup can't answer those in under 10 minutes without SSH-ing into anything, it's not production-ready.

What that looks like in practice:
- A single place to see health of all nine services. Not nine separate places.
- Alarms that mean something. Not "CPU is high" but "order creation rate dropped to zero" or "payment failure rate above 10%."
- Logs you can search across services. "Show me every log line related to order #4271" - across all nine.
- The ability to answer "what's the slowest step in the order flow right now?"

Think about how you'd actually build this. Sidecar per task vs shared log gateway - what are the trade-offs? What does 9 services logging to CloudWatch cost per month? Is there a cheaper way? What happens when your logging pipeline itself goes down?

Bonus: a single order touches five services. Distributed tracing lets you follow a request across all of them. Hard to set up. Invaluable when debugging.

---

## Grading

- All nine services running and healthy
- End-to-end flow works through the UI (create order -> reserve inventory -> process payment -> ship -> deliver)
- Pipeline deploys only what changed
- Secrets not hardcoded anywhere
- No NAT gateways, no long-lived credentials
- README covers all required sections with real decisions, not filler
- You can explain every resource you created

**Tear down when done.** This stack costs money idle.

Everything else is on you. Good luck.

## Service Requirements

| Service | Port | Database | Redis | SQS | Required Environment Variables |
|----------|------|----------|--------|-----|--------------------------------|
| api-gateway | 8080 | ❌ | ✅ | ❌ | JWT_SECRET* |
| order-service | 8081 | ✅ | ❌ | ✅ | DATABASE_URL, SQS_QUEUE_URL |
| inventory-service | 8082 | ✅ | ❌ | ❌ | DATABASE_URL |
| payment-service | 8083 | ✅ | ❌ | ✅ | DATABASE_URL, SQS_QUEUE_URL |
| notification-service | 8084 | ✅ | ❌ | ❌ | DATABASE_URL |
| shipping-service | 8085 | ✅ | ❌ | ✅ | DATABASE_URL, SQS_QUEUE_URL |
| dashboard-api | 8086 | ✅ | ❌ | ❌ | DATABASE_URL |
| worker | 8090 (health) | ❌ | ❌ | ✅ | SQS_QUEUE_URL |
| scheduler | 8091 (health) | ✅ | ❌ | ❌ | DATABASE_URL |

### Notes

- `DATABASE_URL` will be stored in AWS Secrets Manager.
- `JWT_SECRET` will be stored in AWS Secrets Manager.
- `SQS_QUEUE_URL` will be injected from Terraform after queue creation.
- Redis is only used by the API Gateway for rate limiting.
- Service URLs have fallback values in code but will be configured through ECS environment variables in production.

\* `JWT_SECRET` has a fallback value in the code (`change-me-in-production`) but should always be provided securely in production.

## Documentation for me
I NEED TO DO NON ROOT USER FOR DOCKERFILE
bootsrap - s3 - no more dynamodb required for statelock. can now use S3
VPC module is more reusable without vpc-endpoint as some projects might not need sqs or secrets manager end points

For security groups, new AWS provider style, where the rules are separate resources. It creates a rule inside the ALB security group.

IAM Database Authentication

AWS IAM Database Authentication allows applications to connect to an RDS database without storing a long-lived database password. Instead, the application uses its IAM role to generate a temporary authentication token that is valid for approximately 15 minutes. This removes the need to manage or rotate database passwords and follows the principle of least privilege by using short-lived credentials.

IAM Database Authentication is supported by Amazon RDS for PostgreSQL and Amazon RDS for MySQL (and compatible Aurora versions). It is most suitable for applications already running on AWS services that support IAM roles, such as ECS, EC2 or Lambda, because those services can securely obtain temporary credentials without embedding secrets.

Many of these services may connect to PostgreSQL independently. Without a proxy, PostgreSQL has to manage every database connection itself.

IAM Database Authentication

AWS IAM Database Authentication allows applications to connect to an RDS database without storing a long-lived database password. Instead, the application uses its IAM role to generate a temporary authentication token that is valid for approximately 15 minutes. This removes the need to manage or rotate database passwords and follows the principle of least privilege by using short-lived credentials.

IAM Database Authentication is supported by Amazon RDS for PostgreSQL and Amazon RDS for MySQL (and compatible Aurora versions). It is most suitable for applications already running on AWS services that support IAM roles, such as ECS, EC2 or Lambda, because those services can securely obtain temporary credentials without embedding secrets.

Many of these services may connect to PostgreSQL independently. Without a proxy, PostgreSQL has to manage every database connection itself.

### DB Subnet Group

A DB Subnet Group does not create new subnets. It is simply a logical group of existing database subnets (e.g. db-1 and db-2) that tells Amazon RDS where it is allowed to deploy the database. Think of it like a WhatsApp group—you already have the people (subnets), you're just creating a group that contains db-1 and db-2. AWS requires a DB Subnet Group instead of individual subnet IDs so it knows which subnets to use for database deployment and Multi-AZ failover.

### Amazon SQS

Amazon SQS (Simple Queue Service) enables asynchronous communication between microservices by allowing one service to send messages to a queue while another service processes them independently. This decouples services, improves scalability and resilience, and prevents one service from blocking another. A Dead-Letter Queue (DLQ) is configured to capture messages that repeatedly fail processing, making it easier to investigate and retry failed workloads. Long polling is enabled to reduce unnecessary API requests, and server-side encryption is used to protect messages at rest.

### Amazon ElastiCache (Redis)

Amazon ElastiCache for Redis is an in-memory key-value database used to improve application performance by storing frequently accessed or temporary data in RAM instead of querying PostgreSQL every time. Unlike PostgreSQL, Redis is not the source of truth; it is used for caching data such as frequently requested products, sessions, or rate-limiting information. Redis is deployed in private database subnets using a subnet group and a replication group, allowing it to scale with replicas and automatic failover in the future while remaining secure and highly available.

### ALB
* The ALB is the entry point to the application. It receives incoming requests from users but does not send traffic directly to ECS tasks.
* The Listener listens on a specific port (e.g. 80 or 443) and decides what action to take when a request arrives, such as forwarding it to an API Gateway target group or redirecting HTTP to HTTPS.
* The Target Group contains the registered ECS tasks. It performs health checks and distributes incoming requests only to healthy tasks.

### ECS cluster
ECS cluster simply groups your ECS services together. It's a container for your services
Without Container Insights, CloudWatch already gives you some basic ECS metrics.

With Container Insights enabled, you get much more information about your containers.

### IAM
Trust policy = who can use the role
IAM Policy = What are you allowed to do once you’re inside?

Permission policy = what the role can do

The execution role does not use for_each because you normally only need one shared execution role for all ECS services. Every service needs the same basic AWS/ECS permissions: pull image, write logs, retrieve startup secrets.

The task role uses for_each because each application service may need different permissions:

1. Generates a trust policy that defines who can use (assume) the IAM role.
2. Creates the ECS execution role used by ECS itself to pull Docker images, write logs to CloudWatch, and retrieve startup secrets.
3. Attaches the execution policy to the execution role, giving ECS the permissions it needs to pull images, write logs and retrieve startup secrets.
4. Creates a task role for each ECS service. This role is used by the application running inside the container.
5. Generates a permission policy for each task role, defining what AWS resources the service can access (e.g. Secrets Manager or SQS).
6. Creates a real IAM policy in AWS using the JSON generated by the task policy document.
7. Attaches the IAM policy to the corresponding task role so the application receives those permissions.

For the excecution role, AWS has already created the IAM policy for us e.g policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
For the task role 

Execution Role

1. Generate trust policy (who can use the role).
2. Create the execution role.
3. Attach AWS’s existing managed execution policy to give ECS the required permissions.

Task Role

1. Generate trust policy (who can use the role).
2. Create the task role.
3. Generate a permission policy (what the application can do).
4. Create a new IAM policy in AWS from that permission policy.
5. Attach the new IAM policy to the task role.

Permission = one action
Policy = a document containing many permissions

### Cloudwatch
Containers will write things like 
API started on port 8080
Order created
Payment failed
Database connection error

CloudWatch stores those logs so you can inspect and debug your ECS services later.