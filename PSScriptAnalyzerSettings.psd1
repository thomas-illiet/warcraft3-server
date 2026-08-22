@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # Interactive menus intentionally write directly to the host.
        'PSAvoidUsingWriteHost'
        # Internal constructor and serialization helpers do not change external state.
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSingularNouns'
        # Pester mock signatures mirror the functions they replace.
        'PSReviewUnusedParameter'
    )
}
