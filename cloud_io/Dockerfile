FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    openssh-client \
    autossh \
    jq \
    curl \
    bash

# Copy run script and fix line endings + permissions
COPY run.sh /run.sh
RUN sed -i 's/\r$//' /run.sh && \
    chmod 755 /run.sh

CMD [ "/run.sh" ]
