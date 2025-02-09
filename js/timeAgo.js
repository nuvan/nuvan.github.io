const postDatesCollection = document.getElementsByClassName("postedon");

import('https://cdn.jsdelivr.net/npm/date-fns/+esm').then((dateFns) => {

    function timeSince(date) {

        const now = new Date();
        const pastDate = new Date(date);

        let years = dateFns.differenceInYears(now, pastDate);
        let adjustedDate = dateFns.subYears(now, years);
        let months = dateFns.differenceInMonths(adjustedDate, pastDate);

        adjustedDate = dateFns.subMonths(adjustedDate, months);

        let days = dateFns.differenceInDays(adjustedDate, pastDate);
        let result = [];
        let hasYears = false;
        let hasMonths = false;
        let hasDays = false;

        if (years > 0) {
            hasYears = true;
            result.push(`${years} ${years === 1 ? 'year' : 'years'}`);
        }

        if (months > 0) {
            hasMonths = true;
            result.push(`${months} ${months === 1 ? 'month' : 'months'}`);
        }

        if (days > 0 && !(hasYears && hasMonths)) {
            hasDays = true;
            result.push(`${days} ${days === 1 ? 'day' : 'days'}`);
        }

        return result.length > 0 ? result.join(', ') + ' ago.' : 'Today';

    };

    for (let i = 0; i < postDatesCollection.length; i++) {
      var item = postDatesCollection[i];
      var date = Date.parse(item.getAttribute("datetime"));
      var nodes = item.getElementsByClassName("postedago")
      nodes[0].innerHTML = timeSince(date);
    }

});
