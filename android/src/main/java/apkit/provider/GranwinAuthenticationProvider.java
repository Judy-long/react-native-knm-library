package apkit.provider;

import com.amazonaws.auth.AWSAbstractCognitoDeveloperIdentityProvider;
import com.amazonaws.regions.Regions;

public class GranwinAuthenticationProvider extends AWSAbstractCognitoDeveloperIdentityProvider {

    private static final String developerProvider = "granwin";

    public GranwinAuthenticationProvider(String identityId, String token, String accountId, String identityPoolId,
                                         String regin) {
        super(accountId, identityPoolId, Regions.fromName(regin));
        update(identityId,token);
    }
    @Override
    public String getProviderName() {
        return developerProvider;
    }

    // Use the refresh method to communicate with your backend to get an
    // identityId and token.

    @Override
    public String refresh() {
        update(identityId, token);
        return token;

    }

    // If the app has a valid identityId return it, otherwise get a valid
    // identityId from your backend.

    @Override
    public String getIdentityId() {
        return identityId;

    }
}