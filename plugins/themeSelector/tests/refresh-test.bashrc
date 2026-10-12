# Minimal interactive Bash environment used by the Kitty refresh integration
# test. The marker receives one line every time Bash is about to draw a prompt.

PS1='refresh-test> '

record_refresh_test_prompt() {
    printf 'prompt\n' >> "${QS_REFRESH_TEST_MARKER:?}"
}

PROMPT_COMMAND=record_refresh_test_prompt
