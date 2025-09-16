/**
 * Amazon Dashboard Design Tokens
 * Extracted from challenge-Amazon-main CSS and converted to TypeScript
 */
export declare const amazonTokens: {
    readonly colors: {
        readonly primary: "#f79500";
        readonly primaryDark: "#cb7721";
        readonly primaryLight: "#ffb803";
        readonly textPrimary: "#3a4552";
        readonly textSecondary: "#211F1F";
        readonly textDanger: "#f41800";
        readonly background: "#f5f5f5";
        readonly cardBackground: "#fff";
        readonly sidebarBackground: "#fff";
        readonly dropdownBackground: "#ececec";
        readonly border: "#fff";
        readonly inputBorder: "#f79500";
        readonly accent: "#ececec";
        readonly chartAccent: readonly ["#cb7721", "#b05611", "#ffb803", "#F79500", "#803f0c"];
    };
    readonly spacing: {
        readonly sidebarWidth: "16rem";
        readonly sidebarWidthMobile: "12rem";
        readonly contentMarginLeft: "calc(16.3rem + 1rem)";
        readonly contentMarginRight: "1rem";
        readonly cardPadding: "25px";
        readonly cardMargin: "1rem";
        readonly small: "8px";
        readonly medium: "16px";
        readonly large: "24px";
        readonly xlarge: "32px";
    };
    readonly typography: {
        readonly fontFamily: "'Inter', sans-serif";
        readonly fontSize: {
            readonly title: "28px";
            readonly subtitleMedium: "24px";
            readonly subtitleSmall: "16px";
            readonly subtitleColor: "18px";
            readonly sidebar: "12px";
            readonly body: "16px";
            readonly small: "14px";
            readonly table: "13px";
        };
        readonly fontWeight: {
            readonly normal: 400;
            readonly bold: 700;
        };
    };
    readonly shadows: {
        readonly card: "0 6px 8px rgba(89, 87, 87, 0.1)";
        readonly chart: "0 6px 8px rgba(89, 87, 87, 0.1)";
    };
    readonly borderRadius: {
        readonly card: "8px";
        readonly input: "5px";
    };
    readonly layout: {
        readonly breakpoints: {
            readonly mobile: "768px";
        };
        readonly sidebar: {
            readonly width: "16rem";
            readonly mobileWidth: "12rem";
            readonly padding: "1rem";
        };
        readonly content: {
            readonly padding: "1rem";
            readonly marginTop: "2rem";
        };
    };
    readonly components: {
        readonly button: {
            readonly height: "45px";
            readonly width: "120px";
            readonly padding: "10px";
            readonly borderRadius: "5px";
        };
        readonly card: {
            readonly borderWidth: "1px";
            readonly borderRadius: "8px";
            readonly padding: "25px";
            readonly shadow: "0 6px 8px rgba(89, 87, 87, 0.1)";
        };
        readonly icon: {
            readonly size: "30px";
            readonly marginRight: "20px";
            readonly marginBottom: "15px";
        };
        readonly chart: {
            readonly height: "400px";
            readonly loadingColor: "#f79500";
        };
    };
};
export type AmazonTokens = typeof amazonTokens;
