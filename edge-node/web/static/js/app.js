/* ============================================================
   ResQMesh / IgniRelay — Frontend App Logic
   邊緣系統專用 · Alpine.js · < 100KB 極致輕量
   ============================================================ */

document.addEventListener('alpine:init', () => {

  // 1. 系統全域 Store (類似 Vuex/Redux，但極小)
  Alpine.store('app', {
    theme: 'shelter',     // shelter | village | township | fire
    nodeStatus: 'online', // online | syncing | offline | error
    lastSync: null,
    
    // 初始化設定
    initTheme() {
      // 依據後端注入的變數設定，如果沒有就寫死 default
      const el = document.documentElement;
      const theme = el.getAttribute('data-theme') || 'shelter';
      this.theme = theme;
    },

    setSyncStatus(status) {
      this.nodeStatus = status;
    }
  });

  // 2. Dashboard 元件
  Alpine.data('dashboardData', () => ({
    stats: {
      headcount: 0,
      materials: 0,
      active_sos: 0
    },
    events: [],
    loading: true,

    async init() {
      // 初始載入假資料 (後續換成 fetch API)
      this.loading = true;
      try {
        // 模擬網路延遲
        await new Promise(resolve => setTimeout(resolve, 500));
        
        this.stats = {
          headcount: 142,
          materials: 38,
          active_sos: 3,
          headcountTrend: 12
        };

        this.events = [
          { time: '09:30', type: 'resource', text: '王OO 領取飲用水 x2' },
          { time: '09:28', type: 'info', text: '新增收容 3 人（家庭）' },
          { time: '09:15', type: 'warning', text: '里辦公處：物資車 30 分鐘後到' },
          { time: '09:00', type: 'system', text: '系統同步至里節點' }
        ];
      } finally {
        this.loading = false;
      }
    },

    triggerSync() {
      Alpine.store('app').setSyncStatus('syncing');
      setTimeout(() => {
        Alpine.store('app').setSyncStatus('online');
        // Toast logic could go here
        alert('同步完成 (模擬)'); // TODO: 換成自訂 Toast
      }, 1500);
    }
  }));
});
