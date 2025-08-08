import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { next } from "@ember/runloop";

export default class ChatbotTokenStats extends Component {
  @service router;
  @tracked loading = false;
  @tracked usageStats = null;
  @tracked modelStats = null;
  @tracked selectedPeriod = "this_month";
  @tracked activeTab = "overview";
  @tracked chart = null;

  periods = [
    { value: "today", label: "Today" },
    { value: "this_week", label: "This Week" },
    { value: "this_month", label: "This Month" },
  ];

  tabs = [
    { id: "overview", label: "Overview" },
    { id: "models", label: "Models" },
    { id: "users", label: "Users" },
    { id: "export", label: "Export" },
  ];

  constructor() {
    super(...arguments);
    this.loadUsageStats();
  }

  willDestroy() {
    super.willDestroy();
    if (this.chart) {
      this.chart.destroy();
    }
  }

  @action
  async loadUsageStats() {
    this.loading = true;
    try {
      const response = await ajax("/chatbot/admin/token-stats/usage", {
        data: { period: this.selectedPeriod },
      });
      this.usageStats = response;
      
      // Создаем график после загрузки данных
      next(() => {
        this.createChart();
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadModelStats() {
    this.loading = true;
    try {
      const response = await ajax("/chatbot/admin/token-stats/models", {
        data: { period: this.selectedPeriod },
      });
      this.modelStats = response;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async changePeriod(event) {
    const period = event.target.value;
    this.selectedPeriod = period;
    if (this.activeTab === "overview") {
      await this.loadUsageStats();
    } else if (this.activeTab === "models") {
      await this.loadModelStats();
    }
  }

  @action
  async changeTab(tabId) {
    this.activeTab = tabId;
    if (tabId === "overview") {
      await this.loadUsageStats();
    } else if (tabId === "models") {
      await this.loadModelStats();
    }
  }

  @action
  async exportData(format) {
    try {
      window.location.href = `/chatbot/admin/token-stats/export?period=${this.selectedPeriod}&format=${format}`;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async cleanupOldData() {
    if (!confirm("Are you sure you want to delete old token usage data? This action cannot be undone.")) {
      return;
    }

    try {
      const response = await ajax("/chatbot/admin/token-stats/cleanup", {
        type: "DELETE",
        data: { days: 90 },
      });
      
      alert(`Successfully deleted ${response.deleted_count} old records.`);
      await this.loadUsageStats();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  createChart() {
    if (!this.chartData || this.chartData.length === 0) return;
    
    const canvas = document.getElementById('usage-chart');
    if (!canvas) return;
    
    if (this.chart) {
      this.chart.destroy();
    }

    // Простая реализация графика без внешних зависимостей
    const ctx = canvas.getContext('2d');
    this.drawSimpleChart(ctx, canvas);
  }

  drawSimpleChart(ctx, canvas) {
    const data = this.chartData;
    const padding = 40;
    const width = canvas.width - 2 * padding;
    const height = canvas.height - 2 * padding;
    
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Найдем максимальные значения
    const maxCost = Math.max(...data.map(d => d.cost));
    const maxTokens = Math.max(...data.map(d => d.tokens));
    
    // Нарисуем оси
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padding, padding);
    ctx.lineTo(padding, canvas.height - padding);
    ctx.lineTo(canvas.width - padding, canvas.height - padding);
    ctx.stroke();
    
    // Нарисуем график стоимости
    if (maxCost > 0) {
      ctx.strokeStyle = '#3498db';
      ctx.lineWidth = 2;
      ctx.beginPath();
      
      data.forEach((point, index) => {
        const x = padding + (index / (data.length - 1)) * width;
        const y = canvas.height - padding - (point.cost / maxCost) * height;
        
        if (index === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      });
      
      ctx.stroke();
    }
    
    // Добавим подписи
    ctx.fillStyle = '#333';
    ctx.font = '12px sans-serif';
    ctx.fillText('Cost ($)', 10, 20);
    ctx.fillText('Time', canvas.width / 2, canvas.height - 10);
  }

  get totalCostFormatted() {
    if (!this.usageStats?.system_stats?.total_cost) return "$0.00";
    return `$${this.usageStats.system_stats.total_cost.toFixed(4)}`;
  }

  get totalTokensFormatted() {
    if (!this.usageStats?.system_stats?.total_tokens) return "0";
    return this.usageStats.system_stats.total_tokens.toLocaleString();
  }

  get chartData() {
    if (!this.usageStats?.daily_stats) return [];
    
    const data = [];
    Object.entries(this.usageStats.daily_stats).forEach(([date, models]) => {
      let totalCost = 0;
      let totalTokens = 0;
      
      Object.values(models).forEach(model => {
        totalCost += model.cost || 0;
        totalTokens += model.tokens || 0;
      });
      
      data.push({
        date,
        cost: totalCost,
        tokens: totalTokens
      });
    });
    
    return data.sort((a, b) => new Date(a.date) - new Date(b.date));
  }
}
