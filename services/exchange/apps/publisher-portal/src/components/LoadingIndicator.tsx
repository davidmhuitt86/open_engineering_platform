export interface LoadingIndicatorProps {
  label?: string;
}

export function LoadingIndicator({ label = 'Loading…' }: LoadingIndicatorProps): JSX.Element {
  return (
    <div className="loading-indicator" role="status">
      <span className="loading-indicator__spinner" aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}
