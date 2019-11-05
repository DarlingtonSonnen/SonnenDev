/**
 * Dia REST Response
 */
global class DiaRESTResponse {

    String status = 'OK';
    List<SObject> objects = new List<SObject>();
    Map<String,List<SObject>> references = new Map<String,List<SObject>>();
    List<Map<String,String>> gObjects = new List<Map<String,String>>();
    Error error;
    List<String> debug = new List<String>();
    Pagination pagination = new Pagination();
    String objectName;

    public DiaRESTResponse(String objectName) {
        this.objectName = objectName;
    }

    public Pagination getPagination() {
        return this.pagination;
    }

    public void setObjects(List<SObject> objects) {
        this.objects.addAll(objects);
        this.pagination.count = objects.size();
    }

    public void setObjects(List<SObject> objects, Integer countAll) {
        this.objects.addAll(objects);
        this.pagination.count = objects.size();
        this.pagination.countAll = countAll;
    }

    public void setObjects(List<SObject> objects, Integer countAll, Integer pageSize, Integer page) {
        this.objects.addAll(objects);
        this.pagination.countAll = countAll;
        this.pagination.pageSize = pageSize;
        this.pagination.page = page;
        this.pagination.count = objects.size();
    }

    public void setGenericObjects(List<SObject> objects) {

        for (SObject standardObject : objects) {
            String standardObjectAsJson = JSON.serialize(standardObject);
            // Remove attributes
            standardObjectAsJson = standardObjectAsJson.replaceAll('"attributes":\\{"type"[^}]+\\},?', '');
            // Remove subobjects
            standardObjectAsJson = standardObjectAsJson.replaceAll(',?"[^"]+":\\{[^}]+\\}', '');
            Map<String,String> standardObjectFields = (Map<String,String>)JSON.deserialize(standardObjectAsJson , Map<String,String>.class);
            this.gObjects.add(standardObjectFields);
        }
        this.pagination.count = objects.size();
    }

    public void setGenericObjects(List<Map<String,String>> genericObjects) {
		this.gObjects = genericObjects;
        this.pagination.count = genericObjects.size();
    }

    public List<Map<String,String>> getGenericObjects() {
        return this.gObjects;
    }

    public List<SObject> getObjects() {
        return this.objects;
    }

    public void addReferences(String objectName, List<SObject> objects) {
    	this.references.put(objectName, objects);
    }

    public Map<String,List<SObject>> getReferences() {
        return this.references;
    }

    public void addDebug(String message) {
        this.debug.add(message);
    }

    public void setError(Error error) {
        if (error != NULL) {
            status = 'NOK';
            this.error = error;
        }
    }

    public DiaRESTResponse.Error getError() {
        return this.error;
    }

    public void setError(String message, String code) {
        setError(new DiaRESTResponse.Error(message, code));
    }

    public String getStatus() {
        return this.status;
    }

    public Boolean hasError() {
        return (this.error != NULL);
    }

    global class Error {

        public String message;
        public String code;

        public Error(String message, String code) {
            this.message = message;
            this.code = code;
        }
    }

    global class Pagination {
        Integer pageSize = 10;
        Integer page = 1;
        Integer countAll;
        Integer count;
    }
}