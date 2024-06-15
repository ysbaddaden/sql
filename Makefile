.POSIX:
.PHONY:

CRYSTAL = crystal
CRFLAGS =
OPTS =

all: test

test: .PHONY
	$(CRYSTAL) run $(CRFLAGS) test/*_test.cr test/query/*_test.cr -- $(OPTS)
