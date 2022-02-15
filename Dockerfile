FROM docker.io/squidfunk/mkdocs-material:8.1.11

COPY requirements.txt requirements.txt

RUN pip install -r requirements.txt

ENTRYPOINT [ "mkdocs" ]
CMD [ "serve", "--dev-addr=0.0.0.0:8000" ]