.PHONY: test sim build-docker clean

test:
	pytest -v tests/

sim: examples/sample.txt
	python python/codex_sim.py --input-file examples/sample.txt --steps 7 --out trace.json

build-docker:
	docker build -t codex-engine:latest .

run-docker: build-docker
	docker run --rm -v $(PWD)/examples:/data codex-engine:latest --input-file /data/sample.txt --steps 7 --out /data/trace.json

clean:
	rm -f trace.json codex_trace.json
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete

help:
	@echo "Available targets:"
	@echo "  test         - Run pytest tests"
	@echo "  sim          - Run simulation on sample input"
	@echo "  build-docker - Build Docker image"
	@echo "  run-docker   - Build and run in Docker"
	@echo "  clean        - Remove generated files"
