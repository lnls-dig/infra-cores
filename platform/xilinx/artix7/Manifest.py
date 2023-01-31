modules = {
    "local": [
        "chipscope",
        "buffers",
    ]
}

dir_boards_dict = {
    "afc":      "afc_v3",
    "afcv3":    "afc_v3",
    "afcv4":    "afc_v4",
}

try:
    board
except NameError:
    board = "afc"
    print("board property not defined. Using default 'afc'")

assert isinstance(board, str), "'board' property must be a string"
d = dir_boards_dict.get(board, None)
assert d is not None, "unknown name {} in 'dir_boards_dict'".format(board)
modules["local"].append(d)
