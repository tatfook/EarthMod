earthModule.controller("earthController", function ($scope, $http) {
    $scope.confirm = function () {
        if (glat != null && glon != null) {
            $http({
                "method" : "POST",
                "url"    : "/ajax/earth?action=send_coordinate",
                "data": {
                    "lat": glat,
                    "lon": glon
                }
            })
            .then(function (response) {
                console.log(response);
            });
        } else {
            alert("坐标尚未选择");
        }
    }
});