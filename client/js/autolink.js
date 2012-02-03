function autolink(t) {
    var re = /((http|https|ftp):\/\/[\w?=&.\/-;#~%-]+(?![\w\s?&.\/;#~%"=-]*>))/g;
        return t.replace(re, '<a href="$1">$1</a>');
}

