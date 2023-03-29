# The 'prbs_gen' (uut) uses the taps from Table 1 on
# https://www.digikey.com/en/articles/use-readily-available-components-generate-binary-sequences-white-noise.
# For translating those to 'max_len_seq' taps' convention, use:
# [f_{J}, f_{J - 1}, ..., f_{0}] => [nbits, nbits - f_{J}, nbits - f_{J - 1}, ..., nbits - f_{0}].
# TODO: add taps for {2..6}, {9..32}
taps = {
    7 : [7, 0, 1],
    8 : [8, 0, 2, 3, 4],
}
