# Stage 1: Build the application
# Use Java 20 JDK for compilation
FROM eclipse-temurin:20-jdk-jammy as builder
WORKDIR /app

# Copy Maven wrapper and pom.xml to leverage Docker cache
# These files are crucial for Maven to build your project
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download project dependencies. This step can be cached by Docker if pom.xml doesn't change.
# If .mvn/wrapper/maven-wrapper.jar is missing, this command will fail.
RUN ./mvnw dependency:go-offline

# Copy the rest of the source code
# This layer changes most frequently, so it's placed after dependency download.
COPY src src

# Build the Spring Boot application, skipping tests during image build
# The result is typically a JAR file in the 'target/' directory.
RUN ./mvnw clean package -Dmaven.test.skip=true

# Stage 2: Create the final lean image for running the application
# Use Java 20 JRE (smaller runtime environment) based on Alpine Linux for minimal size.
FROM eclipse-temurin:20-jre-alpine
WORKDIR /app

# Create a non-root user for security best practice.
# Running as 'root' inside a container is discouraged.
RUN addgroup --system springboot && adduser --system --ingroup springboot springboot
# Switch to the newly created non-root user.
USER springboot

# Copy the executable JAR from the 'builder' stage into the final image.
# We're only copying the necessary runtime artifact, not the entire build environment.
COPY --from=builder /app/target/*.jar app.jar

# Inform Docker that the container will listen on port 8080.
# This is documentation; actual port mapping happens during 'docker run -p'.
EXPOSE 8080

# Define the command that runs when the container starts.
# This launches your Spring Boot application.
ENTRYPOINT ["java", "-jar", "app.jar"]

# Optional: Define a health check for container orchestration systems (like Kubernetes).
# This periodically checks if your application is responsive (e.g., Spring Boot Actuator).
# HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
#     CMD curl --fail http://localhost:8080/actuator/health || exit 1