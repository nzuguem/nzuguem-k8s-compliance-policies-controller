package me.nzuguem.ac;

import io.fabric8.kubernetes.api.model.*;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionResponseBuilder;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionReview;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionReviewBuilder;
import io.fabric8.kubernetes.api.model.apps.Deployment;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;

@Path("validations")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ValidatingAdmissionController {

    private static final Logger LOGGER = LoggerFactory.getLogger(ValidatingAdmissionController.class);

    @POST
    @Path("images")
    public AdmissionReview validateImages(AdmissionReview admissionReview) {

        LOGGER.info("Received admission review : {}", admissionReview);

        var deployment = (Deployment) admissionReview.getRequest().getObject();
        var containers = deployment.getSpec().getTemplate().getSpec().getContainers();

        var allowed = this.validateContainerImages(containers);

        return new AdmissionReviewBuilder()
                .withResponse(
                        new AdmissionResponseBuilder()
                                .withAllowed(allowed)
                                .withUid(admissionReview.getRequest().getUid())
                                .build()
                ).build();
    }

    private boolean validateContainerImages(List<Container> containers) {
        var patternLatestImage = Pattern.compile("^(.*:latest$|[^:]+)$");

        return containers.stream()
                .noneMatch(container -> patternLatestImage.matcher(container.getImage()).matches());
    }

    @POST
    @Path("labels")
    public AdmissionReview validateLabels(AdmissionReview admissionReview) {

        LOGGER.info("Received admission review : {}", admissionReview);

        var k8sResource =  (HasMetadata) admissionReview.getRequest().getObject();

        var allowed = this.validateLabels(k8sResource.getMetadata().getLabels());

        return new AdmissionReviewBuilder()
                .withResponse(
                        new AdmissionResponseBuilder()
                                .withAllowed(allowed)
                                .withUid(admissionReview.getRequest().getUid())
                                .build()
                ).build();
    }

    private boolean validateLabels(Map<String, String> labels) {

        return labels.containsKey("team") &&
                Objects.nonNull(labels.get("team")) &&
                !labels.get("team").isEmpty();
    }
}
