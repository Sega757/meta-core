.PHONY: test demo observe clean
test:
	python3 -m unittest discover -s tests -v
demo:
	EVENT_LOG_PATH=/tmp/metacore_demo.jsonl python3 examples/demo.py && \
	EVENT_LOG_PATH=/tmp/metacore_demo.jsonl python3 telemetry/observer.py; true
observe:
	python3 telemetry/observer.py
clean:
	rm -f /tmp/metacore_demo.jsonl
