{{- define "fskick.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fskick.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "fskick.postgresName" -}}
{{- printf "%s-postgres" (include "fskick.fullname" .) }}
{{- end }}

{{- define "fskick.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/part-of: {{ include "fskick.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels; pass a dict with "ctx" (root context) and "component". */}}
{{- define "fskick.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fskick.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "fskick.secretEnv" -}}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .ctx.Values.existingSecret }}
      key: {{ .name }}
{{- end }}

{{/*
Environment shared by the migrate initContainer and the app container — the
same variables docker-compose.prod.yml gives both services. The URLs use
Kubernetes' $(VAR) expansion, which only sees variables defined earlier in
the list, so the credentials come first.
*/}}
{{- define "fskick.appEnv" -}}
{{- range list "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB" "EVENT_STORE_DB" "SECRET_KEY_BASE" }}
{{ include "fskick.secretEnv" (dict "ctx" $ "name" .) }}
{{- end }}
- name: DATABASE_URL
  value: "ecto://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@{{ include "fskick.postgresName" . }}/$(POSTGRES_DB)"
- name: EVENT_STORE_URL
  value: "ecto://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@{{ include "fskick.postgresName" . }}/$(EVENT_STORE_DB)"
- name: PHX_HOST
  value: {{ .Values.host | quote }}
- name: POOL_SIZE
  value: {{ .Values.app.poolSize | quote }}
- name: EVENT_STORE_POOL_SIZE
  value: {{ .Values.app.eventStorePoolSize | quote }}
{{- end }}

{{/* Image tag: image.tag when set, otherwise the chart's appVersion. */}}
{{- define "fskick.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "fskick.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "fskick.imageTag" .) }}
{{- end }}
