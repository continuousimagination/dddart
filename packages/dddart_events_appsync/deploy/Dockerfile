FROM dart:3.9.4 AS build
WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe packages/dddart_events_appsync/example/lambda.dart -o /bootstrap

FROM public.ecr.aws/lambda/provided:al2023
COPY --from=build /bootstrap /var/runtime/bootstrap
ENTRYPOINT ["/var/runtime/bootstrap"]
