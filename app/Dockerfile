FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY labgcp ./labgcp
COPY lab.py .
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["python", "lab.py"]
CMD ["worker"]
