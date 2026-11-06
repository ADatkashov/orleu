package com.orleu.arch;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION;
import static com.tngtech.archunit.library.GeneralCodingRules.NO_CLASSES_SHOULD_ACCESS_STANDARD_STREAMS;
import static com.tngtech.archunit.library.GeneralCodingRules.NO_CLASSES_SHOULD_USE_JAVA_UTIL_LOGGING;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

/**
 * Module boundaries of the modular monolith (docs/ARCHITECTURE.md). Each top-level package under com.orleu is a module.
 * These rules run in the normal test task, so a violation fails CI.
 */
@AnalyzeClasses(packages = "com.orleu", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {
    /** No circular dependencies between modules. */
    @ArchTest static final ArchRule modulesHaveNoCycles = slices().matching("com.orleu.(*)..").should().beFreeOfCycles();

    /** publicapi is an entry layer (unauthenticated guest endpoints): feature modules must not depend on it. */
    @ArchTest static final ArchRule nothingDependsOnThePublicApiLayer = noClasses().that().resideOutsideOfPackage("com.orleu.publicapi..")
            .should().dependOnClassesThat().resideInAPackage("com.orleu.publicapi..");

    /** Shared kernel stays at the bottom: common must not know any feature module. */
    @ArchTest static final ArchRule commonDependsOnNoFeatureModule = noClasses().that().resideInAPackage("com.orleu.common..")
            .should().dependOnClassesThat().resideInAnyPackage("com.orleu.admin..", "com.orleu.analytics..", "com.orleu.audit..", "com.orleu.auth..",
                    "com.orleu.bookings..", "com.orleu.business..", "com.orleu.catalog..", "com.orleu.customers..", "com.orleu.notifications..",
                    "com.orleu.payments..", "com.orleu.publicapi..", "com.orleu.reviews..", "com.orleu.scheduling..", "com.orleu.subscriptions..",
                    "com.orleu.support..", "com.orleu.tenancy..");

    /** Identity must not depend on tenancy or any business feature (everything else depends on identity, not the reverse). */
    @ArchTest static final ArchRule authIsIndependentOfBusinessFeatures = noClasses().that().resideInAPackage("com.orleu.auth..")
            .should().dependOnClassesThat().resideInAnyPackage("com.orleu.business..", "com.orleu.tenancy..", "com.orleu.bookings..",
                    "com.orleu.catalog..", "com.orleu.customers..", "com.orleu.payments..", "com.orleu.admin..");

    /** Controllers are entry points; no other class may call them. */
    @ArchTest static final ArchRule controllersAreNotCalledByOtherClasses = noClasses().that().haveSimpleNameNotEndingWith("Controller")
            .should().dependOnClassesThat().haveSimpleNameEndingWith("Controller");

    @ArchTest static final ArchRule noFieldInjection = NO_CLASSES_SHOULD_USE_FIELD_INJECTION;
    @ArchTest static final ArchRule noStandardStreams = NO_CLASSES_SHOULD_ACCESS_STANDARD_STREAMS;
    @ArchTest static final ArchRule noJavaUtilLogging = NO_CLASSES_SHOULD_USE_JAVA_UTIL_LOGGING;
}
