local C = {}

C.VERSION = '1.3.0'

C.MAX_DIALOG_ID = 32767
C.MIN_DIALOG_ID = 15000

C.LIMITS = {
    CAPTION    = 64,
    TOTAL_TEXT = 4096,
    INPUT_TEXT = 128,
    TAB_COL    = 128,
    TAB_ROW    = 256,
    TAB_COLS   = 4,
}

C.STYLE_MAP = {
    msgbox          = 0,
    input           = 1,
    list            = 2,
    password        = 3,
    tablist         = 4,
    tablist_headers = 5,
}

C.LaunchMode = { STANDARD = 1, ROOT = 2, SINGLE_TOP = 3 }

return C