export interface LoadingSpinnerProps {
    size?: 'sm' | 'md' | 'lg' | 'xl';
    color?: 'primary' | 'secondary' | 'white' | 'gray';
    className?: string;
    label?: string;
}
export default function LoadingSpinner({ size, color, className, label }: LoadingSpinnerProps): import("react/jsx-runtime").JSX.Element;
