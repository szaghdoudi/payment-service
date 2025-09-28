FROM eclipse-temurin:25-jre
Workdir /app
COPY target/payment-service-*.jar app.jar
EntryPoint ["java","-jar","app.jar"]