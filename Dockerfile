FROM dart:3.3 AS dependencies
COPY .env .


WORKDIR /.builder

COPY ./app .

RUN dart pub get


RUN dart compile exe --output=./bin/server ./lib/main.dart


######################
#    final stage    #
######################

FROM alpine:latest AS final

RUN apk update && apk add --no-cache gcc libc-dev make libc6-compat curl

WORKDIR /.app

COPY --from=dependencies /.builder/bin/server /.app/server
# create fake .env
RUN echo "DEPLOY=TRUE" > .env

CMD ["/.app/server"]
