FROM base

WORKDIR /app
COPY . /app

# 示例
RUN pip3 install -r requirements.txt

CMD ["python3", "main.py"]
