#ifndef __CHEBY__WB_SI57X_CTRL_REGS__H__
#define __CHEBY__WB_SI57X_CTRL_REGS__H__

#include <stdint.h>

#define WB_SI57X_CTRL_REGS_SIZE 24 /* 0x18 */

/* Si57x control register */
#define WB_SI57X_CTRL_REGS_CTL 0x0UL
#define WB_SI57X_CTRL_REGS_CTL_READ_STRP_REGS 0x1UL
#define WB_SI57X_CTRL_REGS_CTL_APPLY_CFG 0x2UL

/* Status bits */
#define WB_SI57X_CTRL_REGS_STA 0x4UL
#define WB_SI57X_CTRL_REGS_STA_STRP_COMPLETE 0x1UL
#define WB_SI57X_CTRL_REGS_STA_CFG_IN_SYNC 0x2UL
#define WB_SI57X_CTRL_REGS_STA_I2C_ERR 0x4UL
#define WB_SI57X_CTRL_REGS_STA_BUSY 0x8UL

/* HSDIV, N1 and RFREQ higher bits startup values */
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP 0x8UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_RFREQ_MSB_STRP_MASK 0x3fUL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_RFREQ_MSB_STRP_SHIFT 0
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_N1_STRP_MASK 0x1fc0UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_N1_STRP_SHIFT 6
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_HSDIV_STRP_MASK 0xe000UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_HSDIV_STRP_SHIFT 13

/* RFREQ startup value (least significant bits) */
#define WB_SI57X_CTRL_REGS_RFREQ_LSB_STRP 0xcUL

/* HSDIV, N1 and RFREQ higher bits */
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB 0x10UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_RFREQ_MSB_MASK 0x3fUL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_RFREQ_MSB_SHIFT 0
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_N1_MASK 0x1fc0UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_N1_SHIFT 6
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_HSDIV_MASK 0xe000UL
#define WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_HSDIV_SHIFT 13

/* RFREQ (least significant bits) */
#define WB_SI57X_CTRL_REGS_RFREQ_LSB 0x14UL

#ifndef __ASSEMBLER__
struct wb_si57x_ctrl_regs {
  /* [0x0]: REG (rw) Si57x control register */
  uint32_t ctl;

  /* [0x4]: REG (ro) Status bits */
  uint32_t sta;

  /* [0x8]: REG (ro) HSDIV, N1 and RFREQ higher bits startup values */
  uint32_t hsdiv_n1_rfreq_msb_strp;

  /* [0xc]: REG (ro) RFREQ startup value (least significant bits) */
  uint32_t rfreq_lsb_strp;

  /* [0x10]: REG (rw) HSDIV, N1 and RFREQ higher bits */
  uint32_t hsdiv_n1_rfreq_msb;

  /* [0x14]: REG (rw) RFREQ (least significant bits) */
  uint32_t rfreq_lsb;
};
#endif /* !__ASSEMBLER__*/

#endif /* __CHEBY__WB_SI57X_CTRL_REGS__H__ */
