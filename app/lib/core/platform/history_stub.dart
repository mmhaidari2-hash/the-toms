/// No browser history outside the web.
void seedRootHistory() {}

/// Not on the web: let the router pop.
bool historyBack() => false;
