FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    openssh-client \
    autossh \
    jq \
    curl \
    bash

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
