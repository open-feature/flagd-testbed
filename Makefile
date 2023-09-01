.PHONY: clean
clean:
	rm -R bin/
.PHONY: build-sync
build-sync:
	cd sync && go build -o ./bin/sync
