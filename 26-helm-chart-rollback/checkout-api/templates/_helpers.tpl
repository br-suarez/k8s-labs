{{/*
Name helpers. Written by hand rather than taken from `helm create` so every
line is deliberate.
*/}}

{{- define "checkout-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "checkout-api.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "checkout-api.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels split into two sets, and the split matters:

  selectorLabels — go into spec.selector.matchLabels, which is IMMUTABLE on a
                   Deployment. Anything volatile in here makes every upgrade
                   fail with "field is immutable".
  labels         — everything else, including version, which changes constantly.
*/}}
{{- define "checkout-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "checkout-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "checkout-api.labels" -}}
{{ include "checkout-api.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.appVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}
