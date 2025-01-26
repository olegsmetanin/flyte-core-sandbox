{{/*
Expand the name of the chart.
*/}}
{{- define "flyte-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "flyte-proxy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flyte-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flyte-proxy.labels" -}}
helm.sh/chart: {{ include "flyte-proxy.chart" . }}
{{ include "flyte-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flyte-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flyte-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flyte-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flyte-proxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of inline ConfigMap containing additional configuration or overrides for Flyte
*/}}
{{- define "flyte-proxy.configuration.inlineConfigMap" -}}
{{- printf "%s-extra-config" .Release.Name -}}
{{- end }}

{{/*
Name of inline ConfigMap containing additional cluster resource templates
*/}}
{{- define "flyte-proxy.clusterResourceTemplates.inlineConfigMap" -}}
{{- printf "%s-extra-cluster-resource-templates" .Release.Name -}}
{{- end }}

{{/*
Name of PersistentVolume and PersistentVolumeClaim for PostgreSQL database
*/}}
{{- define "flyte-proxy.persistence.dbVolumeName" -}}
{{- printf "%s-db-storage" .Release.Name -}}
{{- end }}

{{/*
Name of PersistentVolume and PersistentVolumeClaim for Minio
*/}}
{{- define "flyte-proxy.persistence.minioVolumeName" -}}
{{- printf "%s-minio-storage" .Release.Name -}}
{{- end }}

{{/*
Selector labels for Buildkit
*/}}
{{- define "flyte-proxy.buildkitSelectorLabels" -}}
{{ include "flyte-proxy.selectorLabels" . }}
app.kubernetes.io/component: buildkit
{{- end }}

{{/*
Selector labels for Envoy proxy
*/}}
{{- define "flyte-proxy.proxySelectorLabels" -}}
{{ include "flyte-proxy.selectorLabels" . }}
app.kubernetes.io/component: proxy
{{- end }}

{{/*
Name of Envoy proxy configmap
*/}}
{{- define "flyte-proxy.proxyConfigMapName" -}}
{{- printf "%s-proxy-config" .Release.Name -}}
{{- end }}

{{/*
Name of development-mode Flyte headless service
*/}}
{{- define "flyte-proxy.localHeadlessService" -}}
{{- printf "%s-local" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
