/**
 * Amazon Dropdown Component
 * Migrated from Dash dcc.Dropdown to React Select
 */

import React from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';

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

export const AmazonDropdown: React.FC<AmazonDropdownProps> = ({
  id,
  options,
  value,
  onChange,
  placeholder = 'Select here',
  clearable = true,
  multi = false,
  className = '',
  disabled = false,
}) => {
  const handleChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const selectedValue = event.target.value;
    if (onChange) {
      onChange(selectedValue === '' ? null : selectedValue);
    }
  };

  const selectStyle: React.CSSProperties = {
    width: '100%',
    height: '45px',
    color: amazonTokens.colors.textPrimary,
    backgroundColor: amazonTokens.colors.dropdownBackground,
    border: `1px solid ${amazonTokens.colors.accent}`,
    borderRadius: amazonTokens.borderRadius.input,
    padding: '0 12px',
    fontSize: amazonTokens.typography.fontSize.body,
    fontFamily: amazonTokens.typography.fontFamily,
    cursor: disabled ? 'not-allowed' : 'pointer',
    outline: 'none',
    transition: 'border-color 0.15s ease',
  };

  const focusStyle = {
    borderColor: amazonTokens.colors.primary,
    boxShadow: `0 0 0 2px ${amazonTokens.colors.primary}20`,
  };

  return (
    <div className={`amazon-dropdown ${className}`}>
      <select
        id={id}
        value={value || ''}
        onChange={handleChange}
        style={selectStyle}
        disabled={disabled}
        multiple={multi}
        onFocus={(e) => {
          Object.assign(e.target.style, focusStyle);
        }}
        onBlur={(e) => {
          e.target.style.borderColor = amazonTokens.colors.accent;
          e.target.style.boxShadow = 'none';
        }}
      >
        {placeholder && (
          <option value="" disabled>
            {placeholder}
          </option>
        )}
        {options.map((option, index) => (
          <option key={index} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>

      {clearable && value && (
        <button
          type="button"
          onClick={() => onChange && onChange(null)}
          style={{
            position: 'absolute',
            right: '30px',
            top: '50%',
            transform: 'translateY(-50%)',
            background: 'none',
            border: 'none',
            color: amazonTokens.colors.textPrimary,
            cursor: 'pointer',
            fontSize: '16px',
            padding: '4px',
          }}
          aria-label="Clear selection"
        >
          ×
        </button>
      )}

      <style>{`
        .amazon-dropdown {
          position: relative;
          display: inline-block;
          width: 100%;
        }

        .amazon-dropdown select:hover {
          border-color: ${amazonTokens.colors.primary} !important;
        }

        .amazon-dropdown select option {
          background-color: ${amazonTokens.colors.cardBackground};
          color: ${amazonTokens.colors.textPrimary};
          padding: 8px 12px;
        }

        .amazon-dropdown select option:hover {
          background-color: ${amazonTokens.colors.accent};
        }
      `}</style>
    </div>
  );
};