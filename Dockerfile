FROM eclipse-temurin:25-jre
WORKDIR /app
COPY target/payment-service-*.jar app.jar
ENTRYPOINT ["java","-jar","app.jar"]