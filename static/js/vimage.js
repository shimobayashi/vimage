$(function() {
    $('#file').on('change', function(event) {
        $('#submit').attr('disabled', true);
        var file = event.target.files[0];
        $('#title').val(file.name)
        var reader = new FileReader();
        reader.onload = function(event) {
            $('#hidden').val(window.btoa(event.target.result));
            $('#submit').removeAttr('disabled' );
        };
        reader.readAsBinaryString(file);
    });
});
