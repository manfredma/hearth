package manfred.hearth.adapter.web.login;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class ConsentPreviewPageController {

    @GetMapping("/consent-preview")
    public String consentPreviewPage() {
        return "forward:/index.html";
    }
}
