# Kubernetes Deployment Guide
## Quiz Stats Animation System

This guide provides Kubernetes manifests for production-grade deployment at scale.

---

## Prerequisites

- Kubernetes cluster (v1.25+)
- kubectl configured
- Helm 3 installed
- Container registry access
- Domain name configured

---

## Architecture Overview

```
                    [Ingress Controller]
                     (nginx-ingress)
                            |
              +-------------+-------------+
              |                           |
      [Backend Service]            [WebSocket Service]
         (ClusterIP)                  (ClusterIP)
              |                           |
    +---------+---------+         +-------+-------+
    |         |         |         |               |
[Backend-1][Backend-2][Backend-3]  [WS Endpoint]
    |         |         |                 |
    +---------+---------+-----------------+
              |
        [Redis Service]
         (ClusterIP)
              |
        [Redis StatefulSet]
         (Persistent Volume)
```

---

## Namespace

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: quiz-stats
  labels:
    name: quiz-stats
    environment: production
```

---

## ConfigMaps

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: quiz-stats
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  BACKEND_PORT: "3000"
  REDIS_URL: "redis://redis-service:6379"
  OPENAI_MODEL: "gpt-3.5-turbo"
  RATE_LIMIT_WINDOW: "900000"
  RATE_LIMIT_MAX: "100"
```

---

## Secrets

```yaml
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: quiz-stats
type: Opaque
stringData:
  OPENAI_API_KEY: "sk-proj-your-api-key-here"
  REDIS_PASSWORD: "your-redis-password"
  JWT_SECRET: "your-jwt-secret"
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: quiz-stats
type: Opaque
stringData:
  redis-password: "your-redis-password"
```

**Create secrets from command line:**
```bash
kubectl create secret generic backend-secrets \
  --from-literal=OPENAI_API_KEY='sk-proj-...' \
  --from-literal=REDIS_PASSWORD='...' \
  --from-literal=JWT_SECRET='...' \
  -n quiz-stats
```

---

## Redis Deployment

```yaml
# redis-statefulset.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: quiz-stats
spec:
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: 6379
      protocol: TCP
      name: redis
  selector:
    app: redis
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: quiz-stats
spec:
  serviceName: redis-service
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command:
          - redis-server
          - --appendonly
          - "yes"
          - --requirepass
          - $(REDIS_PASSWORD)
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: redis-password
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

---

## Backend Deployment

```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: quiz-stats
  labels:
    app: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: ghcr.io/yourusername/quiz-stats/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
          protocol: TCP
        env:
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: NODE_ENV
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: LOG_LEVEL
        - name: BACKEND_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: BACKEND_PORT
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: REDIS_URL
        - name: OPENAI_MODEL
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: OPENAI_MODEL
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: OPENAI_API_KEY
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: REDIS_PASSWORD
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: JWT_SECRET
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1001
          capabilities:
            drop:
            - ALL
      imagePullSecrets:
      - name: ghcr-secret
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: quiz-stats
  labels:
    app: backend
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: backend
```

---

## Horizontal Pod Autoscaler

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: quiz-stats
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
```

---

## Ingress

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  namespace: quiz-stats
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://quiz-stats.example.com"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - quiz-stats.example.com
    secretName: quiz-stats-tls
  rules:
  - host: quiz-stats.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 80
```

---

## Network Policies

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: quiz-stats
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # OpenAI API
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
  namespace: quiz-stats
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 6379
```

---

## Pod Disruption Budget

```yaml
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
  namespace: quiz-stats
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: backend
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: redis-pdb
  namespace: quiz-stats
spec:
  maxUnavailable: 0
  selector:
    matchLabels:
      app: redis
```

---

## Monitoring (ServiceMonitor for Prometheus)

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-metrics
  namespace: quiz-stats
  labels:
    app: backend
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

---

## Deployment Commands

### Apply All Resources

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Apply secrets (use sealed-secrets in production)
kubectl apply -f secrets.yaml

# Apply ConfigMap
kubectl apply -f configmap.yaml

# Deploy Redis
kubectl apply -f redis-statefulset.yaml

# Deploy Backend
kubectl apply -f backend-deployment.yaml

# Apply HPA
kubectl apply -f hpa.yaml

# Apply Network Policies
kubectl apply -f network-policy.yaml

# Apply Pod Disruption Budget
kubectl apply -f pdb.yaml

# Deploy Ingress
kubectl apply -f ingress.yaml

# Apply ServiceMonitor
kubectl apply -f servicemonitor.yaml
```

### Verify Deployment

```bash
# Check all resources
kubectl get all -n quiz-stats

# Check pod status
kubectl get pods -n quiz-stats -w

# Check logs
kubectl logs -f deployment/backend -n quiz-stats

# Check HPA status
kubectl get hpa -n quiz-stats

# Check ingress
kubectl get ingress -n quiz-stats

# Describe deployment
kubectl describe deployment backend -n quiz-stats
```

### Update Deployment

```bash
# Update image
kubectl set image deployment/backend \
  backend=ghcr.io/yourusername/quiz-stats/backend:v1.1.0 \
  -n quiz-stats

# Check rollout status
kubectl rollout status deployment/backend -n quiz-stats

# Rollback if needed
kubectl rollout undo deployment/backend -n quiz-stats

# View rollout history
kubectl rollout history deployment/backend -n quiz-stats
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment backend --replicas=5 -n quiz-stats

# Check current replicas
kubectl get deployment backend -n quiz-stats
```

### Debugging

```bash
# Execute shell in pod
kubectl exec -it deployment/backend -n quiz-stats -- /bin/sh

# Port forward for local testing
kubectl port-forward svc/backend-service 3000:80 -n quiz-stats

# View events
kubectl get events -n quiz-stats --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n quiz-stats
kubectl top nodes
```

---

## Helm Chart (Alternative)

Create a Helm chart for easier management:

```bash
# Create Helm chart
helm create quiz-stats

# Install
helm install quiz-stats ./quiz-stats -n quiz-stats --create-namespace

# Upgrade
helm upgrade quiz-stats ./quiz-stats -n quiz-stats

# Rollback
helm rollback quiz-stats 1 -n quiz-stats

# Uninstall
helm uninstall quiz-stats -n quiz-stats
```

---

## Production Best Practices

1. **Use Sealed Secrets or External Secrets Operator** for secret management
2. **Implement Pod Security Standards** (restricted profile)
3. **Enable Resource Quotas** at namespace level
4. **Use Init Containers** for dependency checks
5. **Implement Readiness Gates** for safe deployments
6. **Use Pod Anti-Affinity** for high availability
7. **Enable Audit Logging** for compliance
8. **Implement Network Policies** for zero-trust security
9. **Use Persistent Volumes** for stateful data
10. **Monitor with Prometheus and Grafana**

---

## CI/CD Integration

Add to GitHub Actions:

```yaml
# .github/workflows/k8s-deploy.yml
- name: Deploy to Kubernetes
  run: |
    kubectl config use-context production
    kubectl set image deployment/backend \
      backend=ghcr.io/${{ github.repository }}/backend:${{ github.sha }} \
      -n quiz-stats
    kubectl rollout status deployment/backend -n quiz-stats
```

---

**Last Updated**: 2025-11-04
