# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Helm charts for self-hosting Inngest, an event-driven application platform. The project enables users to deploy Inngest infrastructure on Kubernetes clusters.

## Requirements

### Kubernetes Requirements

- Kubernetes version 1.20+
- Helm 3.0+
- Persistent Volume support for PostgreSQL and Redis
- LoadBalancer or Ingress controller for external access
- Storage class supporting ReadWriteOnce volumes
- KEDA (optional) for autoscaling based on Prometheus metrics from Inngest service /metrics endpoint on port 8288

### Dependencies

- PostgreSQL (for state management and job storage)
- Redis (for caching and pub/sub messaging)
- Optional: External load balancer or ingress controller

### KEDA Configuration

The chart supports KEDA autoscaling with a Prometheus sidecar:

- Set `keda.enabled: true` in values.yaml
- Prometheus sidecar scrapes metrics from Inngest service /metrics endpoint on port 8288
- The /metrics endpoint requires Bearer token authentication using the signingKey
- Default scaling metric: `inngest_queue_depth` with threshold of 10
- Configurable min/max replicas and scaling intervals
- Lightweight Prometheus sidecar with resource limits

## Development Commands

Common commands for working with this Helm chart:

```bash
# Test template rendering
helm template inngest-dev . --debug

# Lint the chart
helm lint .

# Package Helm chart
helm package .

# Dry run installation
helm install inngest-dev . --dry-run --debug

# Update dependencies
helm dependency update
```

## Repository Structure

This repository follows standard Helm chart structure:

- `Chart.yaml` - Chart metadata and dependencies
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes manifest templates including:
  - Core Inngest deployment and service
  - PostgreSQL and Redis deployments with persistence
  - KEDA ScaledObject for autoscaling
  - ConfigMaps and Secrets for configuration
  - Network policies and ingress
  - Service accounts and RBAC
- `charts/` - Chart dependencies (if any)
- `README.md` - Chart documentation

## Inngest Components

When working with Inngest self-hosting, key components typically include:

- **Event API**: Handles incoming events and webhook delivery
- **Executor**: Processes function executions
- **Runner**: Manages function runtime environments
- **Database**: PostgreSQL for state management
- **Redis**: For caching and pub/sub
- **UI**: Web interface for monitoring and debugging

## Inngest ENV VARS

Inngest has the following env vars that are controlled from a configmap

- **INNGEST_CONFIG**: string Path to an Inngest configuration file
- **INNGEST_EVENT_KEY**: strings Event key(s) that will be used by apps to send events to the server.
- **INNGEST_HELP**: Output this help information
- **INNGEST_HOST**: string Inngest server hostname
- **INNGEST_PORT**: string Inngest server port (default "8288")
- **INNGEST_SDK_URL**: strings App serve URLs to sync (ex. http://localhost:3000/api/inngest)
- **INNGEST_SIGNING_KEY**: string Signing key used to sign and validate data between the server and apps.
- **INNGEST_POSTGRES_URI**: string PostgreSQL database URI for configuration and history persistence. Defaults to SQLite database.
- **INNGEST_REDIS_URI**: string Redis server URI for external queue and run state. Defaults to self-contained, in-memory Redis - server with periodic snapshot backups.
- **INNGEST_SQLITE_DIR**: string Directory for where to write SQLite database.
- **INNGEST_CONNECT_GATEWAY_PORT**: int Port to expose connect gateway endpoint (default 8289)
- **INNGEST_NO_UI**: Disable the web UI and GraphQL API endpoint
- **INNGEST_POLL_INTERVAL**: int Interval in seconds between polling for updates to apps
- **INNGEST_QUEUE_WORKERS**: int Number of executor workers to execute steps from the queue (default 100)
- **INNGEST_RETRY_INTERVAL**: int Retry interval in seconds for linear backoff when retrying functions - must be 1 or above
- **INNGEST_TICK**: int The interval (in milliseconds) at which the executor polls the queue (default 150)
- **INNGEST_JSON**: Output logs as JSON. Set to true if stdout is not a TTY.
- **INNGEST_LOG_LEVEL**: string Set the log level. One of: trace, debug, info, warn, error. (default "info")
- **INNGEST_VERBOSE**: Enable verbose logging.

### Inngest Service Ports

The Inngest self-hosted service exposes two ports:

- **Port 8288**: UI dashboard, Event APIs, other REST APIs, and Prometheus metrics endpoint (/metrics)
- **Port 8289**: Inngest Connect service for function registration and execution

Note: In values.yaml, `service.port` (8288) is the main service port, and `service.connPort` (8289) is the connect gateway port.

## Kubernetes Considerations

- Follow Kubernetes best practices for resource limits, health checks, and security contexts
- Use ConfigMaps and Secrets appropriately for configuration management
- Implement proper RBAC if needed
- Consider using PodDisruptionBudgets for high availability
- Use appropriate storage classes for persistent volumes
- Postgres and Redis are required, either through the instances provided by this helm chart or by external sources provided by a connection string

## Configuration Management

- Use `values.yaml` for all configurable options
- Provide sensible defaults that work out of the box
- Document all configuration options
- Support different deployment scenarios (dev, staging, production)
- Security-focused defaults with non-root containers and read-only filesystems

## Helm Values Configuration

Key configuration sections in values.yaml:

### Required Configuration

- `inngest.eventKey` / `inngest.signingKey` - **REQUIRED** authentication keys
- Must be set before deployment

### Core Application

- `replicaCount` - Number of Inngest pods (default: 1)
- `image.repository` / `image.tag` - Container image configuration
- `resources` - CPU/memory limits and requests

### Dependencies

- `postgresql.enabled` - Deploy internal PostgreSQL (default: true)
- `redis.enabled` - Deploy internal Redis (default: true)
- `inngest.postgres.uri` / `inngest.redis.uri` - External database URIs

### Networking & Access

- `service.type` - Kubernetes service type (default: ClusterIP)
- `ingress.enabled` - Enable ingress for external access
- `networkPolicy.enabled` - Enable network policies for security

### Scaling & Performance

- `keda.enabled` - Enable KEDA autoscaling based on queue depth
- `inngest.queueWorkers` - Number of executor workers (default: 100)
- `inngest.tick` - Queue polling interval in ms (default: 150)

### Security

- Pod and container security contexts with non-root users
- Read-only root filesystems
- Dropped Linux capabilities
- Kubernetes Secrets for sensitive data
