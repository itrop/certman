FROM centos:7 
LABEL maintainer PiotrO <itrop@op.pl>
LABEL description="Checking certificate expiry date for configured servers."

RUN yum install -y openssl which file less

RUN mkdir -p /test
VOLUME /test
WORKDIR /test
COPY certman.sh certman.chk ./

ENV TERM=xterm

ENTRYPOINT ["/test/certman.sh"]
CMD ["-c"]
