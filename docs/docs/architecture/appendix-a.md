# Appendix A: Quick Reference Tables

### A.1 Repository Ownership Matrix

| Repository               | Owner         | Change Frequency | Primary Purpose      |
| ------------------------ | ------------- | ---------------- | -------------------- |
| Platform Charts (Tier 1) | Platform Team | Low (Monthly)    | Template definitions |
| Service Repos (Tier 2)   | Feature Teams | High (Daily)     | Code + configuration |
| GitOps (Tier 3)          | Platform Team | Low (Quarterly)  | Orchestration        |

### A.2 Tool Comparison Matrix

| Capability     | Plain YAML      | Helm         | Helm + Kustomize |
| -------------- | --------------- | ------------ | ---------------- |
| Templating     | None            | Excellent    | Excellent        |
| Versioning     | Git only        | Semantic     | Semantic         |
| Environments   | Duplicate files | Values files | Overlays         |
| Flexibility    | Complete        | Limited      | Excellent        |
| Learning Curve | Low             | Medium       | Medium-High      |

### A.3 Environment Configuration Comparison

| Aspect         | Development      | Staging          | Production            |
| -------------- | ---------------- | ---------------- | --------------------- |
| Replicas       | 1                | 2                | 3-10 (HPA)            |
| Resources      | Minimal (128Mi)  | Moderate (512Mi) | Full (1-4Gi)          |
| Autoscaling    | Disabled         | Optional         | Enabled               |
| Affinity Rules | None             | Zone spreading   | Zone + node spreading |
| Monitoring     | Basic            | Enhanced         | Comprehensive         |
| Chart Version  | Latest (testing) | Current stable   | Proven stable         |

---
