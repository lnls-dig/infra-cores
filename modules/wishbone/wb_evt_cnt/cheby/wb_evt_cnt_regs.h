#ifndef __CHEBY__WB_EVT_CNT_REGS__H__
#define __CHEBY__WB_EVT_CNT_REGS__H__
#define WB_EVT_CNT_REGS_SIZE 8 /* 0x8 */

/* Event counter control register */
#define WB_EVT_CNT_REGS_CTL 0x0UL
#define WB_EVT_CNT_REGS_CTL_TRIG_ACT 0x1UL

/* Counter snapshot register */
#define WB_EVT_CNT_REGS_CNT_SNAP 0x4UL

struct wb_evt_cnt_regs {
  /* [0x0]: REG (rw) Event counter control register */
  uint32_t ctl;

  /* [0x4]: REG (ro) Counter snapshot register */
  uint32_t cnt_snap;
};

#endif /* __CHEBY__WB_EVT_CNT_REGS__H__ */
