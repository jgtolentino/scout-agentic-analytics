/**
 * Amazon Chart Patterns Hook
 * Converts Dash Plotly patterns to React/Plotly.js
 */
export interface ChartData {
    x: (string | number)[];
    y: (string | number)[];
    labels?: string[];
    values?: number[];
    text?: string[];
}
export interface UseAmazonChartsOptions {
    colorScheme?: 'primary' | 'chart' | 'custom';
    customColors?: string[];
}
export declare const useAmazonCharts: (options?: UseAmazonChartsOptions) => {
    createBarChart: (data: ChartData, title: string, options?: {
        showText?: boolean;
        textPosition?: "outside" | "inside" | "auto";
    }) => {
        data: {
            x: (string | number)[];
            y: (string | number)[];
            type: "bar";
            text: string[] | undefined;
            textposition: "auto" | "outside" | "inside";
            texttemplate: string | undefined;
            marker: {
                color: string;
            };
            hoverlabel: {
                bgcolor: string;
                font: {
                    size: number;
                };
            };
            hovertemplate: string;
        }[];
        layout: {
            title: {
                text: string;
                font: {
                    family: "'Inter', sans-serif";
                    size: number;
                    color: "#3a4552";
                };
            };
            xaxis: {
                title: null;
                showticklabels: boolean;
                color: "#3a4552";
            };
            yaxis: {
                title: null;
                showticklabels: boolean;
                color: "#3a4552";
            };
            plot_bgcolor: string;
            paper_bgcolor: string;
            margin: {
                l: number;
                r: number;
                t: number;
                b: number;
            };
            font: {
                family: "'Inter', sans-serif";
                color: "#3a4552";
            };
        };
    };
    createTreemap: (data: ChartData, title: string, options?: {
        maxItems?: number;
        showValues?: boolean;
    }) => {
        data: {
            type: "treemap";
            labels: string[];
            values: number[];
            parents: any[];
            textinfo: string;
            textfont: {
                size: number;
            };
            marker: {
                colors: string[];
            };
        }[];
        layout: {
            title: {
                text: string;
                font: {
                    family: "'Inter', sans-serif";
                    size: number;
                    color: "#3a4552";
                };
            };
            margin: {
                l: number;
                r: number;
                t: number;
                b: number;
            };
            font: {
                family: "'Inter', sans-serif";
                color: "#3a4552";
            };
            hovermode: boolean;
        };
    };
    createPieChart: (data: ChartData, title: string, options?: {
        showPercentages?: boolean;
        hole?: number;
    }) => {
        data: {
            type: "pie";
            labels: string[] | undefined;
            values: number[] | undefined;
            textinfo: string;
            textposition: string;
            hole: number;
            marker: {
                colors: string[] | readonly ["#cb7721", "#b05611", "#ffb803", "#F79500", "#803f0c"];
            };
            hovertemplate: string;
        }[];
        layout: {
            title: {
                text: string;
                font: {
                    family: "'Inter', sans-serif";
                    size: number;
                    color: "#3a4552";
                };
            };
            margin: {
                l: number;
                r: number;
                t: number;
                b: number;
            };
            font: {
                family: "'Inter', sans-serif";
                color: "#3a4552";
            };
            showlegend: boolean;
            legend: {
                orientation: string;
                x: number;
                y: number;
            };
        };
    };
    createHistogram: (data: ChartData, title: string, options?: {
        nbins?: number;
        showDensity?: boolean;
    }) => {
        data: {
            x: (string | number)[];
            type: "histogram";
            nbinsx: number | undefined;
            histnorm: string;
            marker: {
                color: string;
                opacity: number;
            };
            hovertemplate: string;
        }[];
        layout: {
            title: {
                text: string;
                font: {
                    family: "'Inter', sans-serif";
                    size: number;
                    color: "#3a4552";
                };
            };
            xaxis: {
                title: null;
                color: "#3a4552";
            };
            yaxis: {
                title: null;
                color: "#3a4552";
            };
            plot_bgcolor: string;
            paper_bgcolor: string;
            margin: {
                l: number;
                r: number;
                t: number;
                b: number;
            };
            font: {
                family: "'Inter', sans-serif";
                color: "#3a4552";
            };
        };
    };
    colors: string[] | readonly ["#cb7721", "#b05611", "#ffb803", "#F79500", "#803f0c"];
};
