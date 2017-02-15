earthModule.controller("earthController", function ($scope, $http) {
    $scope.confirm = function () {
        if (glng != null && glat != null) {
            $http({
                "method" : "POST",
                "url"    : "/ajax/earth?action=send_coordinate",
                "data": {
                    "lng": glng,
                    "lat": glat
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