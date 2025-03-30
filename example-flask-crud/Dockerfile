FROM python:3.9

WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

RUN apt-get update && apt-get install -y libpq-dev gcc

RUN python3 -m venv venv

RUN /bin/bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

ENV FLASK_APP=crudapp.py
ENV FLASK_RUN_HOST=0.0.0.0

RUN /bin/bash -c "source venv/bin/activate && flask db init && flask db migrate -m 'entries table' && flask db upgrade"

EXPOSE 80

CMD ["/bin/bash", "-c", "source venv/bin/activate && flask run --host=0.0.0.0 --port=80"]