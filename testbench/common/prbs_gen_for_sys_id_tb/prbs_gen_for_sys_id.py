#! /usr/bin/python3

from prbs_max_len import taps
from scipy.signal import max_len_seq
import sys

if len(sys.argv) != 3:
    print(f'Usage: {sys.argv[0]} nbits step_duration')
    sys.exit(1)

nbits, step_duration = sys.argv[1], sys.argv[2]

if int(nbits) in [7, 8]:
    state_i = [0]*(int(nbits) - 1) + [1]
    seq, _ = max_len_seq(nbits=int(nbits), state=state_i, taps=taps[int(nbits)])

    with open(f'prbs_{nbits}_{step_duration}.dat', 'w') as f:
        # After resetting, the first valid state of 'prbs_gen_for_sys_id' is the one after state_i
        for bit in seq[1:]:
            for step in range(int(step_duration)):
                f.write(f'{bit}\n')
        for step in range(int(step_duration)):
            f.write(f'{seq[0]}\n')
else:
    print(f'{nbits} not supported.')
