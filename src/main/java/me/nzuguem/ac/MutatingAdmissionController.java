package me.nzuguem.ac;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.json.JsonMapper;
import io.fabric8.kubernetes.api.model.HasMetadata;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionResponseBuilder;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionReview;
import io.fabric8.kubernetes.api.model.admission.v1.AdmissionReviewBuilder;
import jakarta.json.Json;
import jakarta.json.JsonObject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.StringReader;
import java.util.Base64;
import java.util.Locale;

@Path("mutations")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MutatingAdmissionController {

    private static final Logger LOGGER = LoggerFactory.getLogger(MutatingAdmissionController.class);

    @POST
    @Path("labels")
    public AdmissionReview mutateLabels(AdmissionReview admissionReview) throws JsonProcessingException {

        LOGGER.info("Received admission review : {}", admissionReview);

        var k8sResource =  (HasMetadata) admissionReview.getRequest().getObject();

        var original = this.k8sResourceToJson(k8sResource);

        this.addRecommendedK8sLabels(k8sResource);

        var mutated = this.k8sResourceToJson(k8sResource);

        var patch = Json.createDiff(original, mutated).toString();

        var encoded = Base64.getEncoder().encodeToString(patch.getBytes());

        return new AdmissionReviewBuilder()
                .withResponse(
                        new AdmissionResponseBuilder()
                                .withAllowed()
                                .withUid(admissionReview.getRequest().getUid())
                                .withPatchType("JSONPatch")
                                .withPatch(encoded)
                                .build()
                ).build();
    }

    private void addRecommendedK8sLabels(HasMetadata k8sResource) {

        var labels = k8sResource.getMetadata().getLabels();

        labels.putIfAbsent("app.kubernetes.io/name", k8sResource.getMetadata().getName());
        labels.putIfAbsent("app.kubernetes.io/component", k8sResource.getKind().toLowerCase(Locale.ROOT));
        labels.putIfAbsent("app.kubernetes.io/part-of", k8sResource.getMetadata().getNamespace());
        labels.putIfAbsent("app.kubernetes.io/managed-by", "kubectl");
    }

    private JsonObject k8sResourceToJson(HasMetadata k8sResource) throws JsonProcessingException {

        var k8ResourceJsonString = JsonMapper.builder()
                .build().writeValueAsString(k8sResource);

        try (var jsonReader = Json.createReader(new StringReader(k8ResourceJsonString))){
            return jsonReader.readObject();
        }
    }
}
