/**
 * Amazon Dropdown Component
 * Migrated from Dash dcc.Dropdown to React Select
 */
import React from 'react';
export interface DropdownOption {
    label: string;
    value: string | number;
}
export interface AmazonDropdownProps {
    id?: string;
    options: DropdownOption[];
    value?: string | number | null;
    onChange?: (value: string | number | null) => void;
    placeholder?: string;
    clearable?: boolean;
    multi?: boolean;
    className?: string;
    disabled?: boolean;
}
export declare const AmazonDropdown: React.FC<AmazonDropdownProps>;
