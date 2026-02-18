{{/*
Helper functions for the Inngest Helm chart
These functions generate consistent names, labels, and configuration values
used throughout the chart templates.
*/}}

{{/*
Expand the name of the chart.
Returns the chart name, truncated to 63 characters (Kubernetes limit).
Used for consistent labeling across resources.
*/}}
{{- define "inngest.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
The main Inngest application is always named "inngest" regardless of release name.
This ensures consistent resource naming across different Helm releases, making
scripts and documentation predictable across environments.

Example: Whether you run 'helm install my-prod .' or 'helm install dev .',
the deployment will always be named 'inngest'.
*/}}
{{- define "inngest.fullname" -}}
inngest
{{- end }}

{{/*
Create chart name and version as used by the chart label.
Formats the chart name and version for use in Kubernetes labels.
Replaces '+' with '_' for label compatibility.
*/}}
{{- define "inngest.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
These labels provide metadata about the chart, version, and management.
Used for resource identification, monitoring, and operational queries.
*/}}
{{- define "inngest.labels" -}}
helm.sh/chart: {{ include "inngest.chart" . }}
{{ include "inngest.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used for pod/service matching.
These labels are used by Services to select Pods and should remain stable
across chart upgrades to maintain service connectivity.
*/}}
{{- define "inngest.selectorLabels" -}}
app.kubernetes.io/name: {{ include "inngest.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
===============================================================================
INNGEST SERVER COMPONENT LABELS
Labels for the main Inngest application server component.
===============================================================================
*/}}

{{/*
Inngest server selector labels.
Used by Services to select Pods and by Deployments for pod matching.
*/}}
{{- define "inngest.server.selectorLabels" -}}
app.kubernetes.io/name: inngest
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: server
{{- end }}

{{/*
Inngest server full labels.
Complete set of metadata labels for server resources.
*/}}
{{- define "inngest.server.labels" -}}
helm.sh/chart: {{ include "inngest.chart" . }}
{{ include "inngest.server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/part-of: inngest
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
===============================================================================
POSTGRESQL COMPONENT LABELS
Labels for the PostgreSQL database component.
===============================================================================
*/}}

{{/*
PostgreSQL selector labels.
Used by Services to select Pods and by Deployments for pod matching.
*/}}
{{- define "inngest.postgresql.selectorLabels" -}}
app.kubernetes.io/name: postgresql
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*
PostgreSQL full labels.
Complete set of metadata labels for PostgreSQL resources.
*/}}
{{- define "inngest.postgresql.labels" -}}
helm.sh/chart: {{ include "inngest.chart" . }}
{{ include "inngest.postgresql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.postgresql.image.tag | quote }}
app.kubernetes.io/part-of: inngest
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
===============================================================================
REDIS COMPONENT LABELS
Labels for the Redis cache component.
===============================================================================
*/}}

{{/*
Redis selector labels.
Used by Services to select Pods and by Deployments for pod matching.
*/}}
{{- define "inngest.redis.selectorLabels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: queue
{{- end }}

{{/*
Redis full labels.
Complete set of metadata labels for Redis resources.
*/}}
{{- define "inngest.redis.labels" -}}
helm.sh/chart: {{ include "inngest.chart" . }}
{{ include "inngest.redis.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.redis.image.tag | quote }}
app.kubernetes.io/part-of: inngest
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use.
If serviceAccount.create is true, creates a service account with the specified name.
If no name is specified, uses the fullname template.
If serviceAccount.create is false, uses the specified name or "default".
*/}}
{{- define "inngest.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "inngest.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL resource name.
Returns the consistent name for PostgreSQL-related resources (service, deployment, PVC).
Always returns "inngest-postgresql" regardless of Helm release name.
*/}}
{{- define "inngest.postgresql.fullname" -}}
inngest-postgresql
{{- end -}}

{{/*
Redis resource name.
Returns the consistent name for Redis-related resources (service, deployment, PVC).
Always returns "inngest-redis" regardless of Helm release name.
*/}}
{{- define "inngest.redis.fullname" -}}
inngest-redis
{{- end -}}

{{/*
PostgreSQL connection URI helper.
Generates the PostgreSQL connection URI for Inngest.
Priority:
1. If inngest.postgres.uri is set (external database), use it
2. If postgresql.enabled is true (internal database), construct URI from values
3. Otherwise, return empty (Inngest will use SQLite NOT RECOMMENDED)

The URI is stored in the main Inngest Kubernetes Secret for security.
*/}}
{{- define "inngest.postgresql.uri" -}}
{{- if .Values.inngest.postgres.uri }}
{{- .Values.inngest.postgres.uri }}
{{- else if .Values.postgresql.enabled }}
{{- printf "postgres://%s:%s@%s:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "inngest.postgresql.fullname" .) .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Redis connection URI helper.
Generates the Redis connection URI for Inngest.
Priority:
1. If inngest.redis.uri is set (external Redis), use it
2. If redis.enabled is true (internal Redis), construct URI
3. Otherwise, return empty (Inngest will use in-memory cache NOT RECOMMENDED)
*/}}
{{- define "inngest.redis.uri" -}}
{{- if .Values.inngest.redis.uri }}
{{- .Values.inngest.redis.uri }}
{{- else if .Values.redis.enabled }}
{{- printf "redis://%s:6379" (include "inngest.redis.fullname" .) }}
{{- end }}
{{- end }}