#! /usr/bin/python3

from prbs_max_len import taps
from scipy.signal import max_len_seq
import sys

if len(sys.argv) == 1:
    print(f'Usage: {sys.argv[0]} nbits0 [nbits1 ...]')
    sys.exit(1)

for nbits in sys.argv[1:]:
    if int(nbits) in [7, 8]:
        state_i = [0]*(int(nbits) - 1) + [1]
        seq, _ = max_len_seq(nbits=int(nbits), state=state_i, taps=taps[int(nbits)])

        with open(f'prbs_{nbits}.dat', 'w') as f:
            # After resetting, the first valid state of 'prbs_gen' is the one after state_i
            for bit in seq[1:]:
                f.write(f'{bit}\n')
            f.write(f'{seq[0]}')
    else:
        print(f'{nbits} not supported.')
