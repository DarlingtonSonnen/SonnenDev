public class CustomerToken {

    private static final Blob TOKEN_KEY = CustomerSettingsHelper.getTokenKey();

    public DateTime expireDate;

    public Id userId;

    public CustomerToken(DateTime expireDate, Id userId) {
        this.expireDate = expireDate;
        this.userId = userId;
    }

    public Boolean isExpired() {
        return expireDate < DateTime.now();
    }

    public String encodeToken() {
        String tokenJson = JSON.serialize(this);
        Blob data = Blob.valueOf(tokenJson);
        Blob encrypted = Crypto.encryptWithManagedIV('AES128', TOKEN_KEY, data);
        return EncodingUtil.convertToHex(encrypted);
    }

    public static CustomerToken decodeToken(String token) {
        Blob data = EncodingUtil.convertFromHex(token);
        String tokenJson = Crypto.decryptWithManagedIV('AES128', TOKEN_KEY, data).toString();
        return (CustomerToken) JSON.deserialize(tokenJson, CustomerToken.class);
    }

}