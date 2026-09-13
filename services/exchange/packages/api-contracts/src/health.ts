/** The response shape for `GET /health`. */
export interface HealthCheckResponse {
  status: 'ok';
  version: string;
}
