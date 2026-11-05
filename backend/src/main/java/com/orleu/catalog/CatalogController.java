package com.orleu.catalog;

import com.orleu.catalog.CatalogDtos.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}")
public class CatalogController {
    private final CatalogService service;

    public CatalogController(CatalogService service) { this.service = service; }

    @PostMapping("/branches") @ResponseStatus(HttpStatus.CREATED)
    public BranchView createBranch(@PathVariable UUID businessId, @Valid @RequestBody CreateBranchRequest r) { return service.createBranch(businessId, r); }

    @GetMapping("/branches")
    public List<BranchView> branches(@PathVariable UUID businessId) { return service.listBranches(businessId); }

    @PutMapping("/branches/{branchId}/hours") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void hours(@PathVariable UUID businessId, @PathVariable UUID branchId, @Valid @RequestBody SetHoursRequest r) { service.setHours(businessId, branchId, r); }

    @PostMapping("/services") @ResponseStatus(HttpStatus.CREATED)
    public ServiceView createService(@PathVariable UUID businessId, @Valid @RequestBody CreateServiceRequest r) { return service.createService(businessId, r); }

    @GetMapping("/services")
    public List<ServiceView> services(@PathVariable UUID businessId) { return service.listServices(businessId); }

    @PostMapping("/employees") @ResponseStatus(HttpStatus.CREATED)
    public EmployeeView createEmployee(@PathVariable UUID businessId, @Valid @RequestBody CreateEmployeeRequest r) { return service.createEmployee(businessId, r); }

    @GetMapping("/employees")
    public List<EmployeeView> employees(@PathVariable UUID businessId) { return service.listEmployees(businessId); }

    @PutMapping("/employees/{employeeId}/assignments")
    public EmployeeView assignments(@PathVariable UUID businessId, @PathVariable UUID employeeId, @Valid @RequestBody AssignmentsRequest r) {
        return service.setAssignments(businessId, employeeId, r);
    }

    @PostMapping("/employees/{employeeId}/time-off") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void timeOff(@PathVariable UUID businessId, @PathVariable UUID employeeId, @Valid @RequestBody TimeOffRequest r) { service.addTimeOff(businessId, employeeId, r); }
}
