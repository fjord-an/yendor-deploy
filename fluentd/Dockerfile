FROM fluent/fluentd:v1.16-debian

USER root

# Install plugins
RUN gem install fluent-plugin-s3 \
    fluent-plugin-docker_metadata_filter \
    fluent-plugin-record-modifier \
    fluent-plugin-rewrite-tag-filter

# Copy configuration
COPY fluent.conf /fluentd/etc/fluent.conf

# Create directories
RUN mkdir -p /fluentd/log/buffer /fluentd/log/s3_buffer /fluentd/log/output && \
    chown -R fluent:fluent /fluentd

USER fluent

CMD ["fluentd", "-c", "/fluentd/etc/fluent.conf"]
