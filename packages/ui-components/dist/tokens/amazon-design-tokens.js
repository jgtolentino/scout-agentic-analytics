/**
 * Amazon Dashboard Design Tokens
 * Extracted from challenge-Amazon-main CSS and converted to TypeScript
 */
export const amazonTokens = {
    colors: {
        // Primary Amazon Orange
        primary: '#f79500',
        primaryDark: '#cb7721',
        primaryLight: '#ffb803',
        // Text Colors
        textPrimary: '#3a4552',
        textSecondary: '#211F1F',
        textDanger: '#f41800',
        // Background Colors
        background: '#f5f5f5',
        cardBackground: '#fff',
        sidebarBackground: '#fff',
        dropdownBackground: '#ececec',
        // Border Colors
        border: '#fff',
        inputBorder: '#f79500',
        accent: '#ececec',
        // Chart Colors
        chartAccent: ['#cb7721', '#b05611', '#ffb803', '#F79500', '#803f0c'],
    },
    spacing: {
        // Layout
        sidebarWidth: '16rem',
        sidebarWidthMobile: '12rem',
        contentMarginLeft: 'calc(16.3rem + 1rem)',
        contentMarginRight: '1rem',
        // Card Spacing
        cardPadding: '25px',
        cardMargin: '1rem',
        // General Spacing
        small: '8px',
        medium: '16px',
        large: '24px',
        xlarge: '32px',
    },
    typography: {
        fontFamily: "'Inter', sans-serif",
        fontSize: {
            title: '28px',
            subtitleMedium: '24px',
            subtitleSmall: '16px',
            subtitleColor: '18px',
            sidebar: '12px',
            body: '16px',
            small: '14px',
            table: '13px',
        },
        fontWeight: {
            normal: 400,
            bold: 700,
        },
    },
    shadows: {
        card: '0 6px 8px rgba(89, 87, 87, 0.1)',
        chart: '0 6px 8px rgba(89, 87, 87, 0.1)',
    },
    borderRadius: {
        card: '8px',
        input: '5px',
    },
    layout: {
        breakpoints: {
            mobile: '768px',
        },
        sidebar: {
            width: '16rem',
            mobileWidth: '12rem',
            padding: '1rem',
        },
        content: {
            padding: '1rem',
            marginTop: '2rem',
        },
    },
    components: {
        button: {
            height: '45px',
            width: '120px',
            padding: '10px',
            borderRadius: '5px',
        },
        card: {
            borderWidth: '1px',
            borderRadius: '8px',
            padding: '25px',
            shadow: '0 6px 8px rgba(89, 87, 87, 0.1)',
        },
        icon: {
            size: '30px',
            marginRight: '20px',
            marginBottom: '15px',
        },
        chart: {
            height: '400px',
            loadingColor: '#f79500',
        },
    },
};
