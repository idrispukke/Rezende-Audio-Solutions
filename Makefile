install:
	python -m pip install --upgrade pip
	pip install -r backend/requirements.txt

dev:
	docker-compose -f docker-compose.dev.yml up --build

up:
	docker-compose -f docker-compose.dev.yml up

down:
	docker-compose -f docker-compose.dev.yml down

lint:
	ruff check . || true
	black . --check || true
	mypy src || true

test:
	pytest -q --maxfail=1 || true

build-image:
	docker build -t rezende-backend:local -f backend/Dockerfile backend
